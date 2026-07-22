# Lab d2: Cloud network fabric — VPC, egress, and flow control with Cilium

Build the **classic L3 cloud-network fabric** — VPC dataplane, **NAT-gateway egress**, **cloud-firewall FQDN rules**, and **flow logs** — hands-on, on one kind cluster, for $0, using **Cilium** as the vehicle. Each control is proven by an **observable**: a fixed egress IP seen at an external listener, an FQDN allowlist blocking a non-approved domain, and Hubble showing the allowed vs denied flow. Cluster Mesh (peering) is a walkthrough (needs two clusters).

**Objectives covered**

| id | Objective | Type |
|---|---|---|
| `fab-cni` | Install Cilium as the cluster CNI (the VPC/VNet dataplane) | hands-on |
| `fab-egress` | Pin a fixed SNAT egress IP for selected workloads (NAT gateway) | hands-on |
| `fab-fqdn` | Enforce DNS/FQDN egress rules + host firewall (Azure Firewall app rules) | hands-on |
| `fab-flowlogs` | Observe allowed vs denied flows by identity (NSG/VNet flow logs) | hands-on |
| `fab-peering` | Join two clusters with Cluster Mesh (VNet peering / hub-spoke) | walkthrough |

**SC-500 correspondence**: VNet/VPC dataplane · NAT gateway (controlled egress) · Azure Firewall application rules · NSG/VNet flow logs · VNet peering (hub-spoke). **Standards**: NIST SP 800-207 (controlled egress + micro-segmentation); ATT&CK **T1048** (exfiltration) / **T1071** (C2 over web) ↔ D3FEND outbound-traffic filtering & network traffic analysis; the egress gateway + FQDN allowlist are what deny an attacker's outbound callout.

**Prerequisites**
- `docker`, `kind`, `kubectl`, `helm`; optionally the [`cilium`](https://github.com/cilium/cilium-cli) CLI. ~16 GB host.
- Notes read: [`../domains/0-fundamentals/04-linux-networking.md`](../domains/0-fundamentals/04-linux-networking.md) (the substrate) and [`../domains/2-secrets-data-networking/network-fabric.md`](../domains/2-secrets-data-networking/network-fabric.md) (the cloud mapping).

**Estimated time**: 2–3 h · $0 (local)

> **Directions-first.** Build it yourself from the steps below. A CI-validated **reference solution** lives in [`../lab-infra/network/cilium/`](../lab-infra/network/cilium/); use it to check your work, not to copy.

> **eBPF-fussy hosts (verified):** `fab-cni` and TCP pod-to-pod work on Docker Desktop, but **cluster-external UDP egress** (and therefore external DNS) can be dropped by the Docker Desktop LinuxKit VM under Cilium's eBPF masquerade — you'll see CoreDNS log `read udp …->192.168.65.254:53: i/o timeout` and the FQDN `curl`s below fail even for the allowed name. Run kind inside a **Linux VM** (Lima on macOS, or any Linux host) for Parts B–D — the same fallback the Falco/Tetragon labs use. Part A and the teardown work anywhere.

## Part A — Cilium as the CNI (`fab-cni`)

Create the cluster in **Cilium mode** (no default CNI, no kube-proxy) and install Cilium as the dataplane.

```bash
kind create cluster --name oss500 --config lab-infra/kind/cluster-cilium.yaml
kubectl get nodes            # NotReady — expected: there is no CNI yet

# control-plane IP for kubeProxyReplacement (kube-proxy is disabled)
API_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' oss500-control-plane)
helm repo add cilium https://helm.cilium.io && helm repo update
helm install cilium cilium/cilium --version 1.16.5 -n kube-system \
  -f lab-infra/network/cilium/values.yaml \
  --set k8sServiceHost=$API_IP --set k8sServicePort=6443 --set cluster.name=oss500 --wait
```

**Observable:** nodes transition to `Ready` only once Cilium is up.
```bash
cilium status              # (or) kubectl -n kube-system rollout status ds/cilium
kubectl get nodes          # all Ready now — Cilium owns the dataplane
lab-infra/shared/up.sh     # namespaces + ingress, now that a CNI exists
```

## Part B — fixed egress IP (`fab-egress`) — the NAT gateway

Give pods labelled `egress=gateway` a **fixed** egress IP and prove an external listener sees it, while an unlabeled pod does not.

1. Deploy the demo clients and pick a gateway node:
   ```bash
   kubectl label node oss500-worker egress-gateway=true --overwrite
   kubectl apply -f lab-infra/network/cilium/manifests/clients.yaml
   ```
2. Stand up an **external listener** on the kind docker network (external to the cluster CIDRs) that echoes the caller's source IP:
   ```bash
   docker run -d --name ext-listener --network kind nginxdemos/hello:plain-text
   LISTENER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ext-listener)
   echo "listener at $LISTENER_IP"
   ```
3. Author a `CiliumEgressGatewayPolicy` (see `policies/egress-gateway.yaml`) with `destinationCIDRs: ["$LISTENER_IP/32"]`, `podSelector` matching `egress: gateway` in `oss500-apps`, and `egressGateway.nodeSelector` = `egress-gateway: "true"`. Apply it.
4. The gateway node's IP is the expected source:
   ```bash
   GW_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' oss500-worker)
   echo "gateway node IP = $GW_IP"
   ```

**Observable — the fixed egress IP:**
```bash
# egress-client (labelled) -> listener sees the GATEWAY node IP ($GW_IP)
kubectl -n oss500-apps exec deploy/egress-client -- curl -s http://$LISTENER_IP | grep -i remote_addr
# direct-client (unlabelled) -> listener sees a DIFFERENT IP (its own node)
kubectl -n oss500-apps exec deploy/direct-client -- curl -s http://$LISTENER_IP | grep -i remote_addr
```
The labelled pod's source is pinned to the gateway (fixed, known, allowlist-friendly); the unlabelled pod's is not. That contrast is the NAT-gateway proof.

## Part C — FQDN allowlist + host firewall (`fab-fqdn`) — Azure Firewall app rules

Restrict a workload to a single approved domain, and watch a non-approved one get denied.

1. Apply the FQDN allowlist (`policies/fqdn-allow.yaml`): DNS to CoreDNS **plus** `toFQDNs: docs.cilium.io:443` for `app: fqdn-client`.
   ```bash
   kubectl apply -f lab-infra/network/cilium/policies/fqdn-allow.yaml
   ```

**Observable — allowed succeeds, non-allowlisted denied:**
```bash
kubectl -n oss500-apps exec deploy/fqdn-client -- curl -sS https://docs.cilium.io -o /dev/null -w '%{http_code}\n'          # 200 (allowed)
kubectl -n oss500-apps exec deploy/fqdn-client -- curl -sS --max-time 5 https://example.com -o /dev/null -w '%{http_code}\n' # hangs/fails (DENIED)
```
> If *both* fail to resolve, you forgot the DNS allow rule — the #1 FQDN footgun. The `toFQDNs` set is populated from DNS answers, so DNS to CoreDNS must be permitted with a `dns:` match.

2. **Host firewall (perimeter, in eBPF):** read the header of `policies/host-firewall.yaml`, then apply it by hand — it selects the worker node and default-denies host ingress except in-cluster + an allowlisted admin CIDR. This is the hands-on version of the `net-firewall` appliance walkthrough.
   ```bash
   kubectl apply -f lab-infra/network/cilium/policies/host-firewall.yaml   # careful — see the warning
   ```

## Part D — flow logs with Hubble (`fab-flowlogs`) — NSG/VNet flow logs

See the allowed and the denied flow, attributed by workload identity.

```bash
cilium hubble port-forward &          # or: kubectl -n kube-system port-forward svc/hubble-relay 4245:80
```

**Observable — the allowed vs dropped flow:**
```bash
# regenerate traffic in one shell:
kubectl -n oss500-apps exec deploy/fqdn-client -- sh -c 'curl -s https://docs.cilium.io -o /dev/null; curl -s --max-time 5 https://example.com -o /dev/null || true'
# read it in another:
hubble observe --namespace oss500-apps --to-fqdn docs.cilium.io           # FORWARDED
hubble observe --namespace oss500-apps --verdict DROPPED                   # the example.com drop + deciding policy
```
Each line names the **source and destination identity** and the **verdict** — the identity-attributed equivalent of NSG/VNet flow logs, and the feedback loop the Domain 5 purple-team labs fire against.

## Part E — Cluster Mesh peering (`fab-peering`) — walkthrough

Two clusters exceed the single-host reference, so **walk** the steps (if you have headroom, a second kind cluster runs them for real):

1. Create a second cluster with a **non-overlapping** PodCIDR and a unique `cluster.name`/`cluster.id` (overlapping CIDRs = the mesh won't form).
2. `cilium clustermesh enable` on each; `cilium clustermesh connect --context c1 --destination-context c2`; `cilium clustermesh status` shows the tunnels.
3. Mark a Service `service.cilium.io/global: "true"` for cross-cluster discovery/load-balancing.
4. Write a `CiliumNetworkPolicy` allowing only a specific **remote-cluster identity** (`io.cilium.k8s.policy.cluster: c2`) — peering grants connectivity, **policy still decides reach** (default-deny across the mesh is the zero-trust posture). This is VNet peering / hub-spoke: two isolated fabrics joined, with cross-network policy as the guardrail, and peering is **non-transitive** just like Azure's.

## Teardown
```bash
lab-infra/network/cilium/down.sh          # removes fabric policies + demo workloads
docker rm -f ext-listener                 # the external listener container
kind delete cluster --name oss500         # cleanest full reset (removes Cilium too)
```

## What the exam asks
SC-500 frames these as **NAT Gateway** (controlled egress), **Azure Firewall** (FQDN application rules), **NSG/VNet flow logs**, and **VNet peering**. The transferable concepts: **controlled, attributable egress** through a known IP is a top cloud-network control (it's where you catch and deny exfiltration/C2); **FQDN allowlists** beat IP allowlists for SaaS because names outlive rotating CDN IPs; **flow logs** are what turn "I hope the policy works" into "I can see the allowed and denied flow"; and **peering is connectivity, not trust** — policy still governs what crosses. Whether the tool is Cilium or Azure, the model is identical because both are the same Linux primitives (netns/routing/SNAT/stateful filtering) managed at scale.
