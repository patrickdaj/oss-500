# lab-infra — the OSS-500 lab environment as code

Everything here provisions the open-source security stack **locally**, on a single `kind` cluster plus a few Docker Compose appliances. Each component is self-contained: bring it up for its lab, verify the control, tear it down. Reading the manifests and values is itself study — security-relevant settings are commented against the SC-500 objective they implement.

## Reference host

- **~4 CPU cores, 16 GB RAM, 40 GB free disk.** Every hands-on lab fits if you bring up **only what the current lab needs**.
- Software (day-one baseline): Docker, [kind](https://kind.sigs.k8s.io/), `kubectl`, [Helm](https://helm.sh/), `git`, [`jq`](https://jqlang.github.io/jq/), [Terraform](https://developer.hashicorp.com/terraform/install). Every other CLI the labs use (Vault, Boundary, cert-manager `cmctl`, Trivy, OPA, garak, …) is in [`../TOOLS.md`](../TOOLS.md) with a per-OS install — **grab each as its phase arrives.** No cloud account, no cost.
- The heaviest components — Wazuh + OpenSearch (SIEM) and the full observability stack — should be run alone. Anything that won't fit the reference host is marked `walkthrough` in the tracker.

## Running on Apple Silicon (macOS)

The labs run well on an Apple Silicon Mac (M-series). Two setup notes and one caveat:

- **Give Docker enough memory.** Docker Desktop defaults low (often ~8 GB). Open **Docker Desktop → Settings → Resources → Memory** and set it to **~12–14 GB** (on a 16–18 GB Mac, leave ~4 GB for macOS). Then every individual lab and most phase stacks fit; still run the two heaviest — Wazuh + OpenSearch, and the full observability stack — one at a time.
- **Watch disk, not RAM.** Images and volumes (OpenSearch, Harbor, kind node images, every tool image) can total 20–30 GB. Reclaim space between phases:
  ```bash
  kind delete cluster --name oss500
  docker system prune -af --volumes
  ```
- **Images are arm64.** Almost every chart/image used here is multi-arch, so there's no emulation penalty — and **Ollama uses the Apple GPU (Metal)**, so the AI-security labs run fast. If a rare image is amd64-only, Docker runs it under emulation (slower); the lab notes call those out.
- **eBPF caveat — Falco, Tetragon, and kube-bench node checks.** On Docker Desktop the kernel is a LinuxKit VM, not macOS, so the runtime-detection tools watch that VM's kernel (not your host) and some of kube-bench's node-level CIS checks come back N/A. They usually *run*, but for faithful host-level behavior use a real Linux kernel — a local Lima/Colima/UTM VM (free) or a small cloud VM (e.g. Azure `Standard_B4ms`, destroyed when done). Everything else — including the Suricata/Zeek labs on synthetic traffic — is faithful locally.

## Bring up the cluster (once)

```bash
kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml
lab-infra/shared/up.sh            # namespaces + ingress-nginx (ingress on localhost:8080/8443)
```

Tear the whole thing down at any time with `kind delete cluster --name oss500`.

## Component directories

Each `lab-infra/<component>/` has its own `README.md`, an `up.sh`, and a `down.sh`. Pattern:

```bash
cd lab-infra/<component>
./up.sh          # helm install / kubectl apply / docker compose up
# ...do the matching lab in labs/, verify the control...
./down.sh        # full teardown, no orphaned resources
```

| Component dir | Stack | Phase / objectives |
|---|---|---|
| `kind/`, `shared/` | Cluster, namespaces, ingress | 0 · `gov-iac` |
| `identity/` | Keycloak | 1 · `kc-*` |
| `pam/` | Teleport / Boundary | 1 · `pam-*` |
| `governance/` | Kyverno, OPA Gatekeeper, Kubescape | 1 · `gov-*`, `pod-admission` |
| `secrets/` | Vault (+ injector/CSI) | 2 · `vault-*`, `key-transit` |
| `certs/` | cert-manager | 2 · `cert-*` |
| `network/` | NetworkPolicy sets, service mesh, ingress+WAF | 2 · `net-*`, `waf-*` |
| `encryption/` | etcd EncryptionConfiguration | 2 · `data-encrypt` |
| `runtime/` | Falco, Tetragon, Falcosidekick | 3 · `rt-*` |
| `supplychain/` | Harbor, Trivy, Grype, cosign | 3 · `sc-*`, `sc-scan` |
| `ai/` | Ollama, Open WebUI, NeMo Guardrails, AI gateway | 3 · `ai-*` |
| `observability/` | Prometheus, Grafana, Loki, Tempo, OTel | 4 · `obs-*` |
| `siem/` | Wazuh + OpenSearch (Docker Compose) | 4 · `siem-*` |
| `network-detection/` | Suricata, Zeek (Docker Compose) | 4 · `nid-*` |
| `posture/` | Kubescape, kube-bench | 4 · `vuln-*` |

## Automating with Terraform (optional)

The default automation here is the `up.sh`/`down.sh` wrappers over Helm, `kubectl`, and Docker Compose — chosen so the manifests and values stay readable *as study material* (`gov-iac`). But the entire stack can equally be driven by **Terraform**, and doing so is itself good `gov-iac` practice. Terraform's providers cover every layer used here:

| Layer | Provider | What it replaces |
|---|---|---|
| Cluster | `tehcyx/kind` (local) **or** `hashicorp/azurerm` (AKS / a VM) | `kind create cluster` |
| In-cluster tools (Keycloak, Vault, cert-manager, Falco, Prometheus…) | `hashicorp/helm` → `helm_release` | the `helm install` calls in `up.sh` |
| Policies, RBAC, NetworkPolicy, namespaces | `hashicorp/kubernetes` → `kubernetes_manifest` | the `kubectl apply -f` calls |
| Compose appliances (Wazuh, Suricata, Zeek) | `kreuzwerker/docker` | `docker compose up` |

**The point that makes it portable:** the in-cluster layer (`helm` + `kubernetes`) is **identical whether the cluster is local kind or Azure AKS** — the same `helm_release "vault"` and `kubernetes_manifest "default-deny"` apply to both. Only the *cluster* module changes. A natural layout:

```hcl
# lab-infra/terraform/modules/stack/  — cloud-agnostic: helm_release + kubernetes_manifest
#   for every component, pointed at whatever kubeconfig it's given.
# lab-infra/terraform/local-kind/     — kind_cluster "oss500"  -> module.stack
# lab-infra/terraform/azure-aks/      — azurerm_kubernetes_cluster -> module.stack
```

```hcl
# sketch — one tool, identical for local or Azure:
resource "helm_release" "vault" {
  name       = "vault"
  namespace  = "oss500-secrets"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  values     = [file("${path.module}/../../secrets/values.yaml")] # reuse the same values
}
resource "kubernetes_manifest" "default_deny" {                    # net-policy
  manifest = yamldecode(file("${path.module}/../../network/default-deny.yaml"))
}
```

To go from local to Azure you swap `local-kind/` for `azure-aks/` (or a Linux-VM root) and repoint the kubeconfig — the `module.stack` invocation is unchanged. This mirrors the real SC-500 lesson: infrastructure-as-code that carries the same security controls across environments. The `.tf` roots aren't shipped in this repo (the shell + Helm path is the taught default), but everything above is a complete recipe to add them.

## Naming & labels

- Cluster name: `oss500`. In-cluster resources live in the `oss500-*` namespaces defined in [`shared/namespaces.yaml`](shared/namespaces.yaml) and carry `app.kubernetes.io/part-of: oss500`.
- Find everything for teardown: `kubectl get all -A -l app.kubernetes.io/part-of=oss500`.
- Each Compose appliance uses its own project name (`-p oss500-netdet` for network-detection, `-p oss500-siem` for the SIEM) so tearing one down never removes another's volumes.

## Secrets hygiene

Never commit generated state. Each component provides a `*.example` template for any local value (admin passwords, bootstrap tokens); the real file is gitignored. Vault init output, kubeconfigs, and TLS private keys never enter git.
