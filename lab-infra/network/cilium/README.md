# lab-infra/network/cilium — the cloud-network-fabric (Cilium mode)

The CI-validated **reference solution** for the cloud-network-fabric lab ([`../../../labs/d2-network-fabric.md`](../../../labs/d2-network-fabric.md)). Cilium, installed as the cluster CNI, turns one kind cluster into a teaching surface for the classic L3 cloud-network controls — **VPC dataplane, NAT-gateway egress, cloud-firewall FQDN rules, flow logs** — hands-on, for $0. Build your own from the lab directions first; run this to check or compare.

**Objectives:** `fab-cni`, `fab-egress`, `fab-fqdn`, `fab-flowlogs` (+ `fab-peering` walkthrough)
**SC-500 correspondence:** VNet dataplane · NAT gateway · Azure Firewall (application rules) · NSG/VNet flow logs · VNet peering.
**Standards:** NIST SP 800-207 (controlled egress + micro-segmentation) · CIS network controls · ATT&CK **T1071/T1048** (C2 / exfiltration over the network) ↔ D3FEND network isolation & traffic filtering.

**Footprint:** Cilium agent + operator + Hubble relay/UI ≈ 500–700 MB on top of the cluster. **Time:** install ~3–5 min. Runs on the ~16 GB reference host.

## Prereqs
- A kind cluster created in **Cilium mode** (no default CNI, no kube-proxy):
  ```bash
  kind create cluster --name oss500 --config lab-infra/kind/cluster-cilium.yaml
  ```
- `helm`, `kubectl`, `docker`; optionally the [`cilium`](https://github.com/cilium/cilium-cli) CLI (`cilium status`, `cilium hubble`).
- Cilium **1.16.5** (pinned in `up.sh`) — certified here for egress gateway + FQDN + host firewall + Hubble together on kind.

## Run
```bash
./up.sh        # installs Cilium as the CNI, labels a gateway node, applies fabric policies
./down.sh      # removes the policies + demo workloads (kind delete = full reset)
```
Then run `lab-infra/shared/up.sh` for namespaces + ingress (the nodes go `Ready` only once Cilium is installed).

## What it installs
| File | Control | Cloud analog |
|---|---|---|
| [`values.yaml`](values.yaml) | Cilium CNI, egress gateway, host firewall, Hubble (settings commented against each `fab-*`) | the whole fabric |
| [`policies/egress-gateway.yaml`](policies/egress-gateway.yaml) | `CiliumEgressGatewayPolicy` — fixed SNAT egress IP (`fab-egress`) | NAT gateway |
| [`policies/fqdn-allow.yaml`](policies/fqdn-allow.yaml) | `CiliumNetworkPolicy` `toFQDNs` allowlist (`fab-fqdn`) | Azure Firewall app rules |
| [`policies/host-firewall.yaml`](policies/host-firewall.yaml) | `CiliumClusterwideNetworkPolicy` on the node (`fab-fqdn` host half) — **apply by hand** | perimeter/host firewall |
| [`manifests/clients.yaml`](manifests/clients.yaml) | hardened `egress-client` / `direct-client` / `fqdn-client` pods | the workloads under policy |

## Verify (the observables)
```bash
# fab-fqdn: allowed FQDN succeeds, non-allowlisted FQDN is denied
kubectl -n oss500-apps exec deploy/fqdn-client -- curl -sS https://docs.cilium.io -o /dev/null -w '%{http_code}\n'      # 200
kubectl -n oss500-apps exec deploy/fqdn-client -- curl -sS --max-time 5 https://example.com -o /dev/null -w '%{http_code}\n'  # DENIED
# fab-flowlogs: see the allowed vs dropped flow
cilium hubble port-forward & ; hubble observe --namespace oss500-apps --verdict DROPPED
# fab-egress: an external listener on the kind docker network sees the FIXED gateway IP
#   for egress-client, and a DIFFERENT IP for direct-client (full steps in the lab).
```

## Terraform-automation path
Consistent with the ZTNA labs ([`../../ztna-netbird/`](../../ztna-netbird/) et al.), the whole install is Terraform-automatable — no shell required:
- **`helm` provider** → the Cilium release, pointing `values` at [`values.yaml`](values.yaml) and setting `k8sServiceHost`/`cluster.name` (a `helm_release` resource replaces `up.sh`).
- **`kubernetes` / `kubernetes_manifest` provider** → the `CiliumEgressGatewayPolicy`, `CiliumNetworkPolicy`, and `CiliumClusterwideNetworkPolicy` CRs and the demo workloads.
- Pin the chart version and provider versions in a `versions.tf` exactly as the ZTNA labs do. `up.sh`/`down.sh` are the shell equivalent kept for readability; the IaC objective (`gov-iac`) is served either way.

## `fab-peering` — Cluster Mesh (walkthrough)
Peering needs **two** clusters, beyond the single-host reference, so it stays a walkthrough — full steps in the lab: `cilium clustermesh enable` on each cluster, `cilium clustermesh connect --context <c1> --destination-context <c2>`, then mark a Service `service.cilium.io/global: "true"` for cross-cluster discovery and write a `CiliumNetworkPolicy` that allows a specific remote-cluster identity. That is VNet peering / hub-spoke: two isolated fabrics joined, with policy still deciding reach.

> **eBPF-fussy hosts (verified caveat):** `fab-cni` and TCP pod-to-pod work on Docker Desktop, but **cluster-external UDP egress** (pod → the outside world) can be dropped by the Docker Desktop LinuxKit VM under Cilium's eBPF masquerade — the visible symptom is DNS failing (CoreDNS logs `read udp …->192.168.65.254:53: i/o timeout`), which then makes the FQDN allowlist never populate and `curl` fail even for the allowed name. This is the same eBPF caveat the Falco/Tetragon labs carry. The fix is to run kind inside a **Linux VM** (Lima on macOS, or any Linux host), where the pod→gateway UDP path and the egress gateway work. Bring-up/teardown, `fab-cni`, and the manifests themselves are unaffected — only the egress/FQDN *data-plane observables* need the Linux VM.
