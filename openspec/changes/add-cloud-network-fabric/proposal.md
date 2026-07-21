## Why

OSS-500 brands itself "Cloud & AI Security," but its networking coverage is Kubernetes-pod-centric: NetworkPolicy (NSG micro-segmentation), service-mesh mTLS, ingress, and WAF are hands-on, while the **classic L3 virtual-network fabric** a cloud security engineer must know — VPC/subnet isolation, **NAT gateway / controlled egress with a known egress IP**, cloud firewall (FQDN application rules), route tables, VNet peering, and flow logs — is thin. The Azure Firewall analog (`net-firewall`) is **walkthrough-only**, and there is no hands-on lab for **egress control**, arguably the single most important cloud-network security control. This change closes that gap on a laptop, for $0, using **Cilium** as the vehicle, so the cloud-native networking constructs become buildable-and-verifiable rather than described.

## What Changes

- **New curriculum subsection `d2-fabric`** ("Cloud network fabric: VPC, egress, and flow control") under Domain 2, with objectives that map each classic cloud-network construct to its hands-on OSS equivalent:
  - `fab-cni` — install **Cilium** as the cluster CNI (the eBPF dataplane / VPC substrate) ≈ VNet dataplane
  - `fab-egress` — **Cilium Egress Gateway** = **NAT gateway**: pin a stable SNAT egress IP for selected workloads
  - `fab-fqdn` — **DNS/FQDN-aware egress policy + host firewall** = **Azure Firewall** application rules (**promotes `net-firewall` from walkthrough → hands-on**)
  - `fab-flowlogs` — **Hubble** = **NSG/VNet flow logs** (network observability)
  - `fab-peering` — **Cilium Cluster Mesh** = **VNet peering / hub-spoke** (`walkthrough` — needs two clusters)
- **New fundamentals note** on the raw substrate — Linux network namespaces, bridges, CIDR/subnets, routing (`ip route`), and NAT (`MASQUERADE`) — so the VPC/subnet/route-table mental model is grounded before the Cilium abstractions.
- **`net-firewall` retained but reframed** as the "real network appliance" (OPNsense/pfSense) **walkthrough anchor**, now complemented by the hands-on `fab-fqdn` control.
- **New hands-on lab** `labs/d2-network-fabric.md` (deploy → verify → destroy) proving each control: a fixed egress IP observed at an external listener, an FQDN-allowlist blocking a non-approved domain, Hubble flow visibility, and the peering walkthrough.
- **New lab-infra component** `lab-infra/network/cilium/` (Helm values + up/down), **Terraform-automatable** consistent with the ZTNA labs.
- **Standards grounding** consistent with the repo convention (e.g., NIST 800-207 egress/segmentation, CIS network controls, ATT&CK egress/exfiltration ↔ D3FEND).

## Capabilities

### New Capabilities
- `cloud-network-fabric`: Hands-on coverage of the classic cloud virtual-network constructs (VPC/CNI dataplane, NAT-gateway egress control, cloud-firewall FQDN rules, flow logs, peering) on open-source tooling (Cilium + Linux networking), mapped to their SC-500/Azure equivalents, with a lab and reproducible lab-infra.

### Modified Capabilities
<!-- The build-oss-500-course capabilities are not yet archived to openspec/specs/, so this
     change carries its requirements as a new capability rather than a delta. At apply time it
     also updates shared content (tracker.yaml adds d2-fabric; net-firewall lab: walkthrough→
     retained-as-appliance-walkthrough with fab-fqdn as the hands-on control) — see design.md
     for the reconciliation, since another change (ztna-models-and-purple-team) also edits Domain 2. -->
- None (no archived specs to delta).

## Impact

- **Content (apply-time, coordinate with `ztna-models-and-purple-team`)**: `assessment/data/tracker.yaml` gains the `d2-fabric` subsection (5 objectives) and its `standards` refs; `domains/2-secrets-data-networking/network-security.md` cross-links the new note/lab; a new `domains/0-fundamentals/` netns/CIDR note; `labs/README.md` catalog row; `labs/d2-network-fabric.md`; `lab-infra/network/cilium/`; a quiz addition or new questions in `quiz-2.yaml`.
- **Lab environment**: Cilium replaces kind's default CNI — the cluster bring-up (`lab-infra/kind/`, `lab-infra/shared/`) gains a "Cilium mode" so NetworkPolicy, egress gateway, host firewall, and Hubble work. Reference host unchanged (~16 GB); Cluster Mesh (peering) needs two kind clusters, hence `walkthrough`.
- **study-hub**: none — content-only; the existing `oss500` adapter and globs already render new notes/labs/lab-infra READMEs.
- **Dependencies**: Cilium CLI + Helm chart; `cilium hubble` for flow logs. No cloud account.
