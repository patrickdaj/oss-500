# Cloud network fabric: VPC, egress, and flow control

Domain 2, subsection `d2-fabric`. The rest of Domain 2 secures traffic through the Kubernetes lens — NetworkPolicy (east-west segmentation), mesh mTLS, ingress, WAF. This subsection covers the **classic L3 virtual-network fabric** a cloud security engineer lives in: the **VPC dataplane**, **NAT-gateway egress control**, **cloud-firewall FQDN rules**, **flow logs**, and **peering**. All of it is normally cloud-console-only; here it's **hands-on on one laptop** using **Cilium** (the eBPF CNI) as the vehicle. Ground yourself in the substrate first — [`../0-fundamentals/04-linux-networking.md`](../0-fundamentals/04-linux-networking.md) (netns/CIDR/routing/NAT) and [`../0-fundamentals/07-ebpf-fundamentals.md`](../0-fundamentals/07-ebpf-fundamentals.md) (what an eBPF program actually is and how it attaches, since Cilium's whole dataplane is one) — then build it in the [d2-network-fabric](../../labs/d2-network-fabric.md) lab; environment in [`lab-infra/network/cilium/`](../../lab-infra/network/cilium/).

**Why Cilium:** swapping kind's default CNI for Cilium turns one cluster into a teaching surface for nearly the entire cloud-network control surface — egress gateway = NAT gateway, FQDN policy = Azure Firewall app rules, Hubble = flow logs, Cluster Mesh = peering. The mapping is the point: each control names the Azure/SC-500 construct it stands in for. Standards spine (see [`../standards-map.md`](../standards-map.md)): **NIST SP 800-207** (controlled egress + micro-segmentation), **CIS** network controls, **ATT&CK T1071/T1048** (C2 / exfiltration over the network) ↔ **D3FEND** traffic filtering & network isolation.

## Install Cilium as the cluster CNI (the VPC dataplane)

*Objective: `fab-cni` · OSS: Cilium eBPF CNI ≈ SC-500: VNet/VPC dataplane · Lab: [d2-network-fabric](../../labs/d2-network-fabric.md)*

The **CNI** is the cluster's dataplane — it wires every pod's veth into the node, assigns pod IPs from the node's PodCIDR, and enforces policy. **Cilium** implements this in **eBPF** (programs attached in-kernel — see [`../0-fundamentals/07-ebpf-fundamentals.md`](../0-fundamentals/07-ebpf-fundamentals.md) for what that means) rather than iptables: faster at scale, and *identity-aware* (it keys decisions on a workload **identity** derived from labels, not on ephemeral pod IPs). That identity model is what makes the egress/FQDN/flow-log features possible. This is the VPC/VNet **dataplane** — the fabric everything else rides on.

The cluster is created with **no default CNI and no kube-proxy** so Cilium owns the dataplane:

```yaml
# lab-infra/kind/cluster-cilium.yaml (excerpt)
networking:
  disableDefaultCNI: true    # Cilium becomes the CNI, not kindnet
  kubeProxyMode: none        # Cilium replaces kube-proxy (needed for BPF masquerade)
  podSubnet: "10.244.0.0/16"
```

```bash
# then install Cilium via Helm (kubeProxyReplacement, egress gw, host fw, Hubble)
helm install cilium cilium/cilium --version 1.16.5 -n kube-system -f values.yaml \
  --set k8sServiceHost=<control-plane-IP> --set k8sServicePort=6443
cilium status          # dataplane health; nodes go Ready only once Cilium is up
```

Against SC-500 this is the **VNet dataplane**: in Azure the VNet's dataplane is managed and invisible; on the cluster you install and see it. Same job — move packets between isolated workloads, assign addresses, and be the enforcement point for everything layered on top.

Exam gotchas:

- With `disableDefaultCNI`, nodes stay **NotReady** until a CNI is installed — install Cilium *before* the shared bootstrap, or ingress/CoreDNS can't schedule.
- `kubeProxyReplacement: true` requires the API server reachable directly (kube-proxy is gone) — set `k8sServiceHost/Port`. On kind that's the control-plane container IP.
- Cilium enforces standard `NetworkPolicy` **and** its own richer `CiliumNetworkPolicy` (L7, FQDN, cluster-wide) — the extra L7/FQDN power is why the fabric lab uses Cilium where `net-policy` stays vanilla for portability.

**Resources:**
- [Cilium — Getting Started on kind](https://docs.cilium.io/en/stable/installation/kind/) (~20 min)
- [Cilium concepts — Component Overview (agent, eBPF datapath)](https://docs.cilium.io/en/stable/overview/component-overview/) (~20 min)
- [kubeProxyReplacement](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/) (~15 min)

## Pin a fixed egress IP with the Egress Gateway (NAT gateway)

*Objective: `fab-egress` · OSS: Cilium Egress Gateway ≈ SC-500: NAT gateway / controlled egress · Lab: [d2-network-fabric](../../labs/d2-network-fabric.md)*

**Controlled egress is arguably the single most important cloud-network security control.** By default pods leave the cluster SNAT'd to whatever node they happen to run on — the source IP is unstable and unattributable. A **NAT gateway** fixes egress to one known public IP: a partner can allowlist it, egress is attributable, and unsolicited inbound is impossible. Cilium's **Egress Gateway** is exactly this — SNAT selected pods to a **stable gateway node IP**:

```yaml
apiVersion: cilium.io/v2
kind: CiliumEgressGatewayPolicy
metadata: { name: fixed-egress }
spec:
  selectors:                          # which pods this applies to (by label/namespace)
    - podSelector:
        matchLabels:
          io.kubernetes.pod.namespace: oss500-apps
          egress: gateway
  destinationCIDRs: ["203.0.113.10/32"]   # where to funnel (the external target)
  egressGateway:
    nodeSelector: { matchLabels: { egress-gateway: "true" } }   # the gateway node
```

Now every connection from an `egress=gateway` pod to that CIDR leaves via the gateway node's IP — **fixed and known**. A pod *without* the label leaves with its own node's IP: the side-by-side contrast is the proof (verified in the lab against an external listener). Under the hood this is `MASQUERADE` to a pinned IP, programmed in eBPF (`bpf.masquerade: true`).

Against SC-500 this is **Azure NAT Gateway / controlled egress**: consolidate outbound through a single, allowlist-friendly IP. The security value — **T1048 exfiltration** and **T1071 C2** both go *outbound*; a known egress point is where you attribute, allowlist, and (with FQDN rules below) restrict it (D3FEND outbound-traffic filtering; NIST 800-207 controlled egress).

Exam gotchas:

- Egress gateway is about the **source** IP of outbound traffic (SNAT), not inbound — don't confuse it with a LoadBalancer/ingress IP.
- It needs `bpf.masquerade: true` **and** `kubeProxyReplacement` — SNAT is done in eBPF; leaving kube-proxy in place fights it. This is the finicky-on-kind part (hence the Lima/Linux-VM fallback).
- `destinationCIDRs` should be **specific**, not `0.0.0.0/0` — funneling *all* egress through one node can trip in-cluster reachability and is rarely what you want.
- The gateway node is a single point — in the cloud a NAT gateway is zone-redundant; on kind it's one worker (fine for the lesson).

**Resources:**
- [Cilium Egress Gateway](https://docs.cilium.io/en/stable/network/egress-gateway/egress-gateway/) (~20 min)
- [Azure NAT Gateway — what controlled egress buys you](https://learn.microsoft.com/en-us/azure/nat-gateway/nat-overview) (~15 min)
- [ATT&CK T1048 — Exfiltration Over Alternative Protocol](https://attack.mitre.org/techniques/T1048/) (~10 min, reference)

## Enforce DNS/FQDN egress rules + host firewall (Azure Firewall application rules)

*Objective: `fab-fqdn` · OSS: Cilium FQDN policy + host firewall ≈ SC-500: Azure Firewall (application rules) · Lab: [d2-network-fabric](../../labs/d2-network-fabric.md)*

A NAT gateway controls *where from*; a **cloud firewall** controls *where to* — and modern ones filter by **FQDN**, not just IP, because SaaS endpoints sit behind rotating CDN addresses. This is the **hands-on control that `net-firewall` couldn't provide locally** (that objective stays the appliance walkthrough — see [`network-security.md`](network-security.md)). Cilium's DNS proxy watches a pod's DNS answers and pins the resolved IPs into an allowlist, so the rule follows the **name**:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata: { name: fqdn-allowlist, namespace: oss500-apps }
spec:
  endpointSelector: { matchLabels: { app: fqdn-client } }
  egress:
    - toEndpoints:                          # DNS must be allowed AND is what FQDN matches on
        - matchLabels: { io.kubernetes.pod.namespace: kube-system, k8s-app: kube-dns }
      toPorts:
        - ports: [{ port: "53", protocol: ANY }]
          rules: { dns: [{ matchPattern: "*" }] }
    - toFQDNs: [{ matchName: "docs.cilium.io" }]   # the application allowlist
      toPorts: [{ ports: [{ port: "443", protocol: TCP }] }]
```

`curl https://docs.cilium.io` → **200**; `curl https://example.com` → **denied**. That allowed-vs-denied pair *is* the Azure Firewall application-rule behavior, run locally. The **host-firewall** half (`hostFirewall: true` + a `CiliumClusterwideNetworkPolicy` with a `nodeSelector`) filters the **node itself** — the perimeter/host-firewall analog, enforced in eBPF (apply it by hand and carefully; a wrong host default-deny can wedge kind).

Against SC-500 this is **Azure Firewall application rules** (allow `*.microsoft.com`, deny the rest) plus host-level filtering — centralized, FQDN-aware egress control. Standards: NIST 800-207 (policy-decided egress), D3FEND traffic filtering; the technique it stops is **T1071 (C2 over web)** — an FQDN allowlist denies the beacon's callout home even if the malware runs.

Exam gotchas:

- **FQDN policy depends on DNS visibility** — you must allow DNS to CoreDNS *with a `dns:` rule* so the proxy sees the answers; forget it and either DNS breaks or the FQDN match never populates. This is the #1 FQDN footgun.
- It matches on the **name at resolution time**, pinning the returned IPs — robust to CDN IP rotation in a way an IP allowlist is not.
- **Host firewall** (node traffic) is separate from pod policy and is default-deny once a host policy selects the node — the same care as an nftables edge ruleset; keep the control-plane out of scope on kind.
- FQDN allow ≠ content inspection — it's L7 *names/ports*, not payloads. Deep inspection of the request body is the WAF's job (`waf-*`).

**Resources:**
- [Cilium DNS-based (FQDN) policies](https://docs.cilium.io/en/stable/security/policy/language/#dns-based) (~20 min)
- [Cilium Host Firewall](https://docs.cilium.io/en/stable/security/host-firewall/) (~15 min)
- [Azure Firewall application rules (FQDN filtering)](https://learn.microsoft.com/en-us/azure/firewall/features#application-fqdn-filtering-rules) (~15 min)

## See every flow with Hubble (NSG / VNet flow logs)

*Objective: `fab-flowlogs` · OSS: Hubble ≈ SC-500: NSG / VNet flow logs · Lab: [d2-network-fabric](../../labs/d2-network-fabric.md)*

You can't secure what you can't see. Cloud fabrics emit **flow logs** — a record of who talked to whom, on what port, allowed or denied. **Hubble** is Cilium's flow-observability layer: because Cilium sees every packet in eBPF *with workload identity attached*, Hubble shows flows labeled by **source/dest identity**, not just IPs, and — crucially — the **verdict** (FORWARDED vs DROPPED) with the policy that decided it.

```bash
cilium hubble port-forward &
hubble observe --namespace oss500-apps --verdict DROPPED     # the denied flows
hubble observe --namespace oss500-apps --to-fqdn example.com # trace the FQDN denial
# each line: source-identity -> dest-identity  :port  VERDICT (policy)
```

Apply the FQDN policy above, generate the allowed and denied requests, and read both flows in Hubble — an allowed `fqdn-client → docs.cilium.io:443 FORWARDED` and a dropped `fqdn-client → example.com DROPPED`. That is exactly how **NSG/VNet flow logs** attribute traffic in Azure, made real-time and identity-aware here.

Against SC-500 this is **NSG flow logs / VNet flow logs** (and Traffic Analytics): the observability that turns a policy from "I hope it's working" into "I can see the allowed and the denied flow." It's the Detect half of NIST CSF for the network, and the feedback loop the purple-team labs (Domain 5) fire against.

Exam gotchas:

- Hubble attributes by **identity**, not IP — a dropped flow tells you *which workload* and *which policy*, the thing raw NSG logs make you reverse-engineer from addresses.
- `--verdict DROPPED` is the fastest way to debug "why is this blocked" — the answer includes the deciding policy.
- Flow logs are **observability, not enforcement** — Hubble sees and records; the egress/FQDN policies enforce. (Azure NSG flow logs are likewise passive.)
- Relay (`hubble-relay`) aggregates across nodes; without it `hubble observe` only sees the local node.

**Resources:**
- [Hubble — setup & observability](https://docs.cilium.io/en/stable/observability/hubble/) (~20 min)
- [Azure NSG flow logs / VNet flow logs](https://learn.microsoft.com/en-us/azure/network-watcher/vnet-flow-logs-overview) (~15 min)

## Peer two clusters with Cluster Mesh (VNet peering / hub-spoke) — walkthrough

*Objective: `fab-peering` · OSS: Cilium Cluster Mesh ≈ SC-500: VNet peering / hub-spoke · Lab: [d2-network-fabric](../../labs/d2-network-fabric.md) (walkthrough)*

**Walkthrough** — peering joins **two** virtual networks, and two kind clusters exceed the single-host reference, so study the model with the exact steps. **VNet peering** connects two VPCs so their private CIDRs route to each other *without going over the internet*, and policy still governs what may cross — the basis of **hub-spoke** topologies (shared services in a hub, workloads in spokes). **Cilium Cluster Mesh** is the analog: it joins two clusters into one policy and service-discovery domain.

```bash
# on each cluster (non-overlapping PodCIDRs, unique cluster.name/id — like non-overlapping VPC CIDRs)
cilium clustermesh enable --context c1
cilium clustermesh enable --context c2
cilium clustermesh connect --context c1 --destination-context c2      # exchange the peering
cilium clustermesh status --context c1                                 # tunnels established
```

```yaml
# a Service marked global is discoverable/load-balanced across both clusters
metadata:
  annotations: { service.cilium.io/global: "true" }
---
# and policy still decides reach — allow only a specific remote-cluster identity
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
spec:
  endpointSelector: { matchLabels: { app: api } }
  ingress:
    - fromEndpoints: [{ matchLabels: { io.cilium.k8s.policy.cluster: c2, app: web } }]
```

Against SC-500 this is **VNet peering / hub-spoke**: two isolated fabrics joined so private traffic routes directly, with **cross-network policy** as the guardrail. The zero-trust point (NIST 800-207): peering grants *connectivity*, not *trust* — a `CiliumNetworkPolicy` on the remote identity is what actually authorizes the cross-cluster call, exactly as an NSG still gates traffic across a VNet peering.

Exam gotchas:

- **Non-overlapping PodCIDRs and unique cluster IDs are mandatory** — overlapping ranges make cross-cluster routing ambiguous and the mesh won't form (the CIDR-planning lesson from fundamentals, at cluster scale).
- Peering is **routing + discovery, not a trust grant** — global services are reachable, but `CiliumNetworkPolicy` still decides who may call; default-deny across the mesh is the secure posture.
- Peering is **non-transitive** (like Azure VNet peering): A–B and B–C do not give A–C — hub-spoke needs explicit routes/policy or a transit design.
- It's `walkthrough` here purely for host headroom — the steps and the model are examined at full depth.

**Resources:**
- [Cilium Cluster Mesh — setup](https://docs.cilium.io/en/stable/network/clustermesh/clustermesh/) (~25 min)
- [Cluster Mesh — global services & policy](https://docs.cilium.io/en/stable/network/clustermesh/services/) (~15 min)
- [Azure VNet peering (hub-spoke reference)](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke) (~20 min)

## Summary

| Objective | Cilium mechanism | Cloud construct | Takeaway |
|---|---|---|---|
| `fab-cni` | eBPF CNI (kube-proxy-free) | VNet/VPC dataplane | Identity-aware dataplane; install before the CNI-less nodes can go Ready |
| `fab-egress` | Egress Gateway (pinned SNAT) | NAT gateway | Fixed, known, attributable egress IP — the top egress control; needs `bpf.masquerade` |
| `fab-fqdn` | FQDN policy + host firewall | Azure Firewall app rules | Allow by DNS name (deny the rest); the hands-on control `net-firewall` lacked; allow DNS or it breaks |
| `fab-flowlogs` | Hubble | NSG/VNet flow logs | Identity-attributed allowed vs DROPPED flows; observability, not enforcement |
| `fab-peering` | Cluster Mesh | VNet peering / hub-spoke | Join two fabrics; non-overlapping CIDRs; peering ≠ trust, policy still decides (walkthrough) |
