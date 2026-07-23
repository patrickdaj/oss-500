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
- Tools for this lab: `cilium`, `hubble` — install per [`../TOOLS.md`](../TOOLS.md).

**Estimated time**: 2–3 h · $0 (local)

> **Directions-first.** Build it yourself from the steps below. A CI-validated **reference solution** lives in [`../lab-infra/network/cilium/`](../lab-infra/network/cilium/); use it to check your work, not to copy.

> **eBPF-fussy hosts (verified):** `fab-cni` and TCP pod-to-pod work on Docker Desktop, but **cluster-external UDP egress** (and therefore external DNS) can be dropped by the Docker Desktop LinuxKit VM under Cilium's eBPF masquerade — you'll see CoreDNS log `read udp …->192.168.65.254:53: i/o timeout` and the FQDN `curl`s below fail even for the allowed name. Run kind inside a **Linux VM** (Lima on macOS, or any Linux host) for Parts B–D — the same fallback the Falco/Tetragon labs use. Part A and the teardown work anywhere.

## Challenge

Build the fabric yourself and reach five observables — one per objective. No solutions below; the concrete artifacts (Helm values, `CiliumEgressGatewayPolicy`, `CiliumNetworkPolicy`, host firewall) live in `lab-infra/network/cilium/` for you to check against once you've built your own — not to copy up front.

- **`fab-cni`**: bring every kind node to `Ready` with Cilium as the *only* CNI — no default CNI, no kube-proxy.
- **`fab-egress`**: pin pods labelled `egress=gateway` to a **fixed** SNAT egress IP. An external listener must see the **gateway node's IP** for the labelled pod, and a **different** IP for an unlabelled pod.
- **`fab-fqdn`**: restrict a workload to exactly one approved FQDN (`docs.cilium.io` on 443) — the allowed domain returns `200`, every other domain is denied — then add a host-level perimeter firewall.
- **`fab-flowlogs`**: make Hubble show the *same* traffic as one **FORWARDED** flow and one **DROPPED** flow, each attributed to workload identity, not just an IP.
- **`fab-peering`** *(walkthrough)*: reason through joining two clusters with Cluster Mesh so cross-cluster traffic is *possible* but still policy-gated — connectivity is not trust.

## Build it (guided)

### Part A — Cilium as the CNI (`fab-cni`)

**Goal:** a kind cluster with no default CNI and no kube-proxy, with Cilium installed as the dataplane.

- **This lab is the exception — it rebuilds the cluster.** Every other lab reuses the shared Phase 0 `oss500` cluster, but `fab-cni` intentionally needs one built with **no default CNI and no kube-proxy**, so delete the standard cluster first: `kind delete cluster --name oss500`. (When you finish this lab, recreate the standard cluster for the others: `kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml` then `lab-infra/shared/up.sh`.)
- The kind cluster config that disables the default CNI and kube-proxy already exists at `lab-infra/kind/cluster-cilium.yaml` — create the cluster from it. Nodes will come up `NotReady`; that's expected, there's no CNI yet.
- Cilium needs to reach the API server directly since kube-proxy is disabled (`kubeProxyReplacement`). The control-plane node is a docker container, not a host IP — how do you get a container's network IP from the docker CLI?
- Add the Cilium Helm repo and install the `cilium/cilium` chart into `kube-system`, using the values file at `lab-infra/network/cilium/values.yaml` plus the API server IP/port and a cluster name so Cilium is happy without kube-proxy.
- **Your turn:** create the cluster, resolve the API IP, and run the helm install. Don't move on until every node shows `Ready`.

```bash
kubectl get nodes            # check readiness as you go
cilium status                # (or) kubectl -n kube-system rollout status ds/cilium
```

Once nodes are `Ready`, bring up the lab namespaces: `lab-infra/shared/up.sh`.

### Part B — fixed egress IP (`fab-egress`) — the NAT gateway

**Goal:** pods labelled `egress=gateway` leave the cluster through one node's IP; unlabelled pods don't.

1. Deploy the demo clients from `lab-infra/network/cilium/manifests/clients.yaml` (an `egress-client` labelled `egress: gateway`, and a `direct-client` left unlabelled for contrast) and label a node to be the gateway (`egress-gateway=true`).
2. Stand up an **external listener** — outside the cluster's CIDRs, on the kind docker network — that echoes back the caller's source IP (an `nginxdemos/hello:plain-text` container works). Note its container IP; that's the target your egress policy will funnel toward.
3. **Author a `CiliumEgressGatewayPolicy`.** It needs: a `podSelector` matching `egress: gateway` in `oss500-apps`, `destinationCIDRs` scoped to the listener's `/32` (using `0.0.0.0/0` funnels *all* cluster egress and can break in-cluster reachability — don't), and `egressGateway.nodeSelector` matching your gateway node's label. Write it, apply it, then compare against the worked example at `lab-infra/network/cilium/policies/egress-gateway.yaml`.
4. Note the gateway node's own IP too (same docker-inspect trick as Part A) — that's the value you expect to see once the policy is live.

**Check yourself** against the Verification observable below: the labelled pod's traffic should arrive at the listener from the *gateway node's* IP; the unlabelled pod's should not.

### Part C — FQDN allowlist + host firewall (`fab-fqdn`) — Azure Firewall app rules

**Goal:** `fqdn-client` may reach `docs.cilium.io` on 443 and nothing else; a host firewall then locks down the node's own perimeter.

1. **Write the allowlist.** A `CiliumNetworkPolicy` selecting `app: fqdn-client` needs *two* egress rules: DNS to CoreDNS (`k8s-app: kube-dns`) on port 53 with a `dns: matchPattern: "*"` rule, **and** a `toFQDNs: matchName: docs.cilium.io` rule on port 443. Order and completeness both matter.
   > The #1 FQDN footgun: skip the DNS allow rule and *both* the allowed and the denied domain fail to resolve — `toFQDNs` is populated from watched DNS answers, so DNS must be permitted first.
   Write your own policy, apply it, then diff against the worked example at `lab-infra/network/cilium/policies/fqdn-allow.yaml`.
2. **Host firewall (perimeter, in eBPF).** This is the hands-on version of the `net-firewall` appliance walkthrough. Before applying anything by hand, read the header of `lab-infra/network/cilium/policies/host-firewall.yaml` — a host policy selecting the wrong node (or missing an allow rule) can wedge the kube-apiserver/kubelet path and force a full cluster rebuild. Notice how its `nodeSelector` deliberately targets workers only, and how it keeps in-cluster/health/remote-node traffic flowing before it default-denies the rest.

**Check yourself** against the Verification observable below: the allowed FQDN returns `200`; the non-allowlisted one hangs/fails.

### Part D — flow logs with Hubble (`fab-flowlogs`) — NSG/VNet flow logs

**Goal:** see the allowed and the denied flow from Part C, each attributed to the actual workload identity.

- Get Hubble reachable locally — port-forward the relay, or use the `cilium` CLI's own helper.
- **Your turn:** regenerate the Part C traffic (the allowed request, then the denied one) in one shell, and read `hubble observe` in another.

Inspection commands (these aren't the solution, they're how you look — feel free to use them as-is):
```bash
cilium hubble port-forward &          # or: kubectl -n kube-system port-forward svc/hubble-relay 4245:80
```
```bash
hubble observe --namespace oss500-apps --to-fqdn docs.cilium.io           # FORWARDED
hubble observe --namespace oss500-apps --verdict DROPPED                   # the example.com drop + deciding policy
```
Each line names the **source and destination identity** and the **verdict** — the identity-attributed equivalent of NSG/VNet flow logs, and the feedback loop the Domain 5 purple-team labs fire against.

### Part E — Cluster Mesh peering (`fab-peering`) — walkthrough

Two clusters exceed the single-host reference, so **walk** the steps (if you have headroom, a second kind cluster runs them for real):

1. Create a second cluster with a **non-overlapping** PodCIDR and a unique `cluster.name`/`cluster.id` (overlapping CIDRs = the mesh won't form).
2. `cilium clustermesh enable` on each; `cilium clustermesh connect --context c1 --destination-context c2`; `cilium clustermesh status` shows the tunnels.
3. Mark a Service `service.cilium.io/global: "true"` for cross-cluster discovery/load-balancing.
4. Write a `CiliumNetworkPolicy` allowing only a specific **remote-cluster identity** (`io.cilium.k8s.policy.cluster: c2`) — peering grants connectivity, **policy still decides reach** (default-deny across the mesh is the zero-trust posture). This is VNet peering / hub-spoke: two isolated fabrics joined, with cross-network policy as the guardrail, and peering is **non-transitive** just like Azure's.

## Verification

- **`fab-cni`** — nodes transition to `Ready` only once Cilium is up:
  ```bash
  cilium status              # (or) kubectl -n kube-system rollout status ds/cilium
  kubectl get nodes          # all Ready now — Cilium owns the dataplane
  ```
- **`fab-egress`** — the fixed egress IP:
  ```bash
  # egress-client (labelled) -> listener sees the GATEWAY node IP ($GW_IP)
  kubectl -n oss500-apps exec deploy/egress-client -- curl -s http://$LISTENER_IP | grep -i remote_addr
  # direct-client (unlabelled) -> listener sees a DIFFERENT IP (its own node)
  kubectl -n oss500-apps exec deploy/direct-client -- curl -s http://$LISTENER_IP | grep -i remote_addr
  ```
  The labelled pod's source is pinned to the gateway (fixed, known, allowlist-friendly); the unlabelled pod's is not. That contrast is the NAT-gateway proof.
- **`fab-fqdn`** — allowed succeeds, non-allowlisted denied:
  ```bash
  kubectl -n oss500-apps exec deploy/fqdn-client -- curl -sS https://docs.cilium.io -o /dev/null -w '%{http_code}\n'          # 200 (allowed)
  kubectl -n oss500-apps exec deploy/fqdn-client -- curl -sS --max-time 5 https://example.com -o /dev/null -w '%{http_code}\n' # hangs/fails (DENIED)
  ```
  > If *both* fail to resolve, you forgot the DNS allow rule — the #1 FQDN footgun. The `toFQDNs` set is populated from DNS answers, so DNS to CoreDNS must be permitted with a `dns:` match.
- **`fab-flowlogs`** — the allowed vs dropped flow:
  ```bash
  # regenerate traffic in one shell:
  kubectl -n oss500-apps exec deploy/fqdn-client -- sh -c 'curl -s https://docs.cilium.io -o /dev/null; curl -s --max-time 5 https://example.com -o /dev/null || true'
  # read it in another:
  hubble observe --namespace oss500-apps --to-fqdn docs.cilium.io           # FORWARDED
  hubble observe --namespace oss500-apps --verdict DROPPED                   # the example.com drop + deciding policy
  ```
  Each line names the source and destination identity and the verdict — the identity-attributed equivalent of NSG/VNet flow logs, and the feedback loop the Domain 5 purple-team labs fire against.
- **`fab-peering`** *(walkthrough)*: no local observable — verify understanding by being able to describe what `cilium clustermesh status` shows once tunnels are up, and why the cross-cluster `CiliumNetworkPolicy` is what actually gates reach, not the mesh connection itself.

## Reference solution
Build it yourself first; check after. A CI-validated version of everything below lives in [`../lab-infra/network/cilium/`](../lab-infra/network/cilium/).

### Part A — Cilium as the CNI (`fab-cni`)
```bash
kind delete cluster --name oss500                                          # this lab rebuilds the cluster (no default CNI / no kube-proxy)
kind create cluster --name oss500 --config lab-infra/kind/cluster-cilium.yaml
kubectl get nodes            # NotReady — expected: there is no CNI yet

# control-plane IP for kubeProxyReplacement (kube-proxy is disabled)
API_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' oss500-control-plane)
helm repo add cilium https://helm.cilium.io && helm repo update
helm install cilium cilium/cilium --version 1.16.5 -n kube-system \
  -f lab-infra/network/cilium/values.yaml \
  --set k8sServiceHost=$API_IP --set k8sServicePort=6443 --set cluster.name=oss500 --wait
```
```bash
cilium status              # (or) kubectl -n kube-system rollout status ds/cilium
kubectl get nodes          # all Ready now — Cilium owns the dataplane
lab-infra/shared/up.sh     # namespaces + ingress, now that a CNI exists
```
Values file: [`lab-infra/network/cilium/values.yaml`](../lab-infra/network/cilium/values.yaml).

### Part B — fixed egress IP (`fab-egress`)
```bash
kubectl label node oss500-worker egress-gateway=true --overwrite
kubectl apply -f lab-infra/network/cilium/manifests/clients.yaml
```
```bash
docker run -d --name ext-listener --network kind nginxdemos/hello:plain-text
LISTENER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ext-listener)
echo "listener at $LISTENER_IP"
```
`CiliumEgressGatewayPolicy` with `destinationCIDRs: ["$LISTENER_IP/32"]`, `podSelector` matching `egress: gateway` in `oss500-apps`, and `egressGateway.nodeSelector` = `egress-gateway: "true"` — [`lab-infra/network/cilium/policies/egress-gateway.yaml`](../lab-infra/network/cilium/policies/egress-gateway.yaml):
```bash
kubectl apply -f lab-infra/network/cilium/policies/egress-gateway.yaml
```
```bash
GW_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' oss500-worker)
echo "gateway node IP = $GW_IP"
```
Demo workloads: [`lab-infra/network/cilium/manifests/clients.yaml`](../lab-infra/network/cilium/manifests/clients.yaml) (`egress-client`, `direct-client`, `fqdn-client`).

### Part C — FQDN allowlist + host firewall (`fab-fqdn`)
FQDN allowlist — DNS to CoreDNS **plus** `toFQDNs: docs.cilium.io:443` for `app: fqdn-client` — [`lab-infra/network/cilium/policies/fqdn-allow.yaml`](../lab-infra/network/cilium/policies/fqdn-allow.yaml):
```bash
kubectl apply -f lab-infra/network/cilium/policies/fqdn-allow.yaml
```
Host firewall — selects the worker node and default-denies host ingress except in-cluster + an allowlisted admin CIDR; read the header before applying — [`lab-infra/network/cilium/policies/host-firewall.yaml`](../lab-infra/network/cilium/policies/host-firewall.yaml):
```bash
kubectl apply -f lab-infra/network/cilium/policies/host-firewall.yaml   # careful — see the warning
```

### Part D — flow logs with Hubble (`fab-flowlogs`)
```bash
cilium hubble port-forward &          # or: kubectl -n kube-system port-forward svc/hubble-relay 4245:80
```
Traffic-generation and `hubble observe` commands are in Verification above (identical commands — this control has no separate deployable artifact beyond the port-forward).

### Part E — Cluster Mesh peering (`fab-peering`) — walkthrough
No deployable artifact beyond the CLI invocations already given in Build it (guided):
1. Second cluster, non-overlapping PodCIDR, unique `cluster.name`/`cluster.id`.
2. `cilium clustermesh enable` on each; `cilium clustermesh connect --context c1 --destination-context c2`; `cilium clustermesh status` shows the tunnels.
3. `service.cilium.io/global: "true"` on the shared Service.
4. A `CiliumNetworkPolicy` keyed on `io.cilium.k8s.policy.cluster: c2` — connectivity from peering, reach from policy.

## Teardown
```bash
lab-infra/network/cilium/down.sh          # removes fabric policies + demo workloads
docker rm -f ext-listener                 # the external listener container
kind delete cluster --name oss500         # cleanest full reset (removes Cilium too)
```

## What the exam asks
SC-500 frames these as **NAT Gateway** (controlled egress), **Azure Firewall** (FQDN application rules), **NSG/VNet flow logs**, and **VNet peering**. The transferable concepts: **controlled, attributable egress** through a known IP is a top cloud-network control (it's where you catch and deny exfiltration/C2); **FQDN allowlists** beat IP allowlists for SaaS because names outlive rotating CDN IPs; **flow logs** are what turn "I hope the policy works" into "I can see the allowed and denied flow"; and **peering is connectivity, not trust** — policy still governs what crosses. Whether the tool is Cilium or Azure, the model is identical because both are the same Linux primitives (netns/routing/SNAT/stateful filtering) managed at scale.
