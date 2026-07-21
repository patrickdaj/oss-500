## Context

OSS-500's Domain 2 covers networking through the Kubernetes lens: `net-policy` (NetworkPolicy ≈ NSG), `net-mesh` (mTLS ≈ Private Link), `net-ingress` (≈ App Gateway), `net-firewall` (OPNsense/pfSense ≈ Azure Firewall, **walkthrough**), plus `d2-waf` and the `d1-ztna` access models. What's missing is the classic **L3 virtual-network fabric** — VPC/subnet isolation, **NAT-gateway egress control**, cloud-firewall FQDN rules, flow logs, and peering — which is central to real cloud security work (egress control and network isolation above all).

The constraint that shapes the design: it must be **hands-on on a single ~16 GB laptop for $0**. A real VPC/NAT/firewall appliance (OPNsense) wants its own NICs and is impractical to run meaningfully there — which is exactly why `net-firewall` is a walkthrough today. The insight of this change is that **Cilium**, installed as the cluster CNI, reproduces almost the entire cloud-network control surface *inside a single kind cluster*.

This change is authored as an isolated OpenSpec change while another change (`ztna-models-and-purple-team`) is actively editing Domain 2 content. It therefore specifies behavior and defers all shared-file edits to a coordinated apply.

## Goals / Non-Goals

**Goals:**
- Make the classic cloud-network constructs — VPC dataplane, **NAT-gateway egress**, cloud-firewall FQDN rules, flow logs — **hands-on and verifiable** on the local cluster.
- Ground them in Linux networking fundamentals (netns/CIDR/routing/NAT) so the mental model transfers to any cloud.
- Keep the OPNsense/pfSense appliance model as the walkthrough anchor; keep everything Terraform-automatable like the ZTNA labs.
- Map every construct explicitly to its SC-500/Azure equivalent and its standard.

**Non-Goals:**
- Not replacing NetworkPolicy/mesh/ingress/WAF — this complements them at the L3 fabric layer.
- Not a production multi-cluster build: **peering (Cluster Mesh) stays a walkthrough** (two clusters exceed the single-host reference).
- Not running a real OPNsense/pfSense appliance hands-on — it remains the conceptual walkthrough.
- Not editing shared content in this change's authoring pass — only at apply time, coordinated.

## Decisions

**D1 — Cilium is the vehicle.** Swapping kind's default CNI for Cilium turns one laptop cluster into a teaching surface for nearly every cloud-network construct:

| Cloud construct | Cilium mechanism | Objective |
|---|---|---|
| VPC/VNet dataplane | Cilium eBPF CNI | `fab-cni` |
| **NAT gateway** (fixed egress IP) | **Egress Gateway** (SNAT to a stable IP) | `fab-egress` |
| **Azure Firewall** (FQDN app rules) | DNS/FQDN-aware egress policy + host firewall (`CiliumClusterwideNetworkPolicy`) | `fab-fqdn` |
| NSG/VNet **flow logs** | **Hubble** | `fab-flowlogs` |
| **VNet peering** / hub-spoke | **Cluster Mesh** (walkthrough) | `fab-peering` |
| Cloud LB (L4) | LB-IPAM / L2 announcements (optional mention) | — |

*Alternatives:* Calico — strong NetworkPolicy but weaker egress-gateway/FQDN/observability story than Cilium+Hubble; nftables/OPNsense alone — the real appliance, but not laptop-hands-on (kept as walkthrough); MetalLB — complements for L4 LB, noted, not core.

**D2 — Fundamentals-first for the substrate.** Cilium abstracts subnets/routes/NAT; a learner who's never seen `ip route`, a bridge, a CIDR split, or `MASQUERADE` will treat the abstractions as magic. A `domains/0-fundamentals/` note (netns, bridges, CIDR, routing, NAT) precedes the fabric material so the VPC/subnet/route-table model is concrete and cloud-portable.

**D3 — Promote the control, keep the appliance.** `net-firewall` (OPNsense/pfSense) stays as the appliance **walkthrough** anchor — it's the truest 1:1 to the Azure networking stack (zones + NAT + firewall + VPN + routes in one box) and worth studying. `fab-fqdn` supplies the **hands-on** enforcement (FQDN allowlist actually blocking a domain) that `net-firewall` couldn't provide locally. So the change adds a hands-on control without deleting the conceptual anchor.

**D4 — Cilium is a cluster "mode," not a hard replacement.** `lab-infra/kind/` + `lab-infra/shared/` gain a documented Cilium bring-up path (kind created with default CNI disabled, Cilium installed via Helm with egress gateway + host firewall + Hubble). Labs that don't need the fabric still run on the default cluster; the fabric lab (and, if desired, the NetworkPolicy lab) use Cilium mode. This avoids forcing every learner onto Cilium while making the fabric controls available.

**D5 — Apply-time reconciliation with `ztna-models-and-purple-team`.** Both changes touch Domain 2 (`tracker.yaml`, `network-security.md`, `labs/README.md`, `quiz-2.yaml`, `lab-infra/network/`). This change specifies *additive* content (a new `d2-fabric` subsection, a new `lab-infra/network/cilium/` dir, a new lab file, appended quiz questions) chosen to minimize overlap. At apply time the implementer MUST re-read the then-current tracker/notes/catalog and insert `d2-fabric` after `d2-network`, reusing whatever `standards`/ID conventions the other change established. New objective ids (`fab-*`) and the new lab-infra dir do not collide with ZTNA ids (`ztna-*`) or dirs.

## Risks / Trade-offs

- **Cilium adds cluster complexity and image weight.** → Make it an opt-in "Cilium mode" for the fabric lab, not the default for every lab; document the footprint. Cilium on kind is well-supported and fits the reference host.
- **Egress Gateway on kind can be finicky** (needs a stable node IP / the feature enabled at install). → Pin a tested Cilium version and Helm values; provide the external-listener verification so success is unambiguous; if a given kernel balks, document the Lima/Linux-VM fallback (same as the eBPF caveat for Falco/Tetragon).
- **Peering can't be hands-on on one host.** → Explicitly `walkthrough` with full Cluster Mesh steps; note a two-kind-cluster option for those with headroom.
- **Overlap with the in-flight ztna change.** → Additive-only design + apply-time reconciliation note (D5); distinct ids and dirs; no shared-file edits during authoring.
- **Scope creep toward "reimplement all of cloud networking."** → Bound to five constructs that map cleanly to Cilium features + one fundamentals note; LB/DDoS mentioned, not built.

## Migration Plan

Additive. Apply after (or in coordination with) `ztna-models-and-purple-team` to avoid tracker/catalog churn. Apply steps: add `d2-fabric` to `tracker.yaml`; write the fabric note + fundamentals note; add `lab-infra/network/cilium/` and the Cilium bring-up path; write `labs/d2-network-fabric.md`; add catalog row; append `quiz-2.yaml` questions for `fab-*`; run `gen:md` and study-hub `lint:content` + tests. Rollback is deletion of the additive files + tracker entries; nothing else depends on them.

## Open Questions

- Cilium **version pin** to certify egress-gateway + FQDN + Hubble together on kind (Docker Desktop LinuxKit) — pick one and document the Lima/Linux-VM fallback.
- Put the netns/CIDR substrate note in `0-fundamentals/` (ramp) or as the first `d2-fabric` note? (Lean `0-fundamentals/` so it's reusable and keeps the fabric note focused on the cloud mapping.)
- Should the existing `net-policy` lab optionally run in Cilium mode to show CiliumNetworkPolicy L7 + Hubble, or stay vanilla NetworkPolicy? (Lean: keep `net-policy` vanilla for portability; showcase Cilium-specific power in the fabric lab.)
