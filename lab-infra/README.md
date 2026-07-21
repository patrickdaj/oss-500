# lab-infra — the OSS-500 lab environment as code

Everything here provisions the open-source security stack **locally**, on a single `kind` cluster plus a few Docker Compose appliances. Each component is self-contained: bring it up for its lab, verify the control, tear it down. Reading the manifests and values is itself study — security-relevant settings are commented against the SC-500 objective they implement.

## Reference host

- **~4 CPU cores, 16 GB RAM, 40 GB free disk.** Every hands-on lab fits if you bring up **only what the current lab needs**.
- Software: Docker, [kind](https://kind.sigs.k8s.io/), `kubectl`, [Helm](https://helm.sh/). No cloud account, no cost.
- The heaviest components — Wazuh + OpenSearch (SIEM) and the full observability stack — should be run alone. Anything that won't fit the reference host is marked `walkthrough` in the tracker.

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

## Naming & labels

- Cluster name: `oss500`. In-cluster resources live in the `oss500-*` namespaces defined in [`shared/namespaces.yaml`](shared/namespaces.yaml) and carry `app.kubernetes.io/part-of: oss500`.
- Find everything for teardown: `kubectl get all -A -l app.kubernetes.io/part-of=oss500`.
- Compose appliances use the `oss500` project name (`docker compose -p oss500 …`).

## Secrets hygiene

Never commit generated state. Each component provides a `*.example` template for any local value (admin passwords, bootstrap tokens); the real file is gitignored. Vault init output, kubeconfigs, and TLS private keys never enter git.
