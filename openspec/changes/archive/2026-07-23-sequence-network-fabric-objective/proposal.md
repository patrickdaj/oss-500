# Sequence (or explicitly de-scope) the orphaned d2-fabric objective

## Why

`d2-fabric` ("Cloud network fabric: VPC, egress, and flow control" — Cilium eBPF CNI) is a **fully built but unsequenced** objective:

- It is a tracked objective in `assessment/data/tracker.yaml` with five subsections (`fab-cni`, `fab-egress`, `fab-fqdn`, `fab-flowlogs`, `fab-peering`),
- it has a note (`domains/2-secrets-data-networking/network-fabric.md`), a large lab (`labs/d2-network-fabric.md`), and a `lab-infra/network/cilium/` component,
- and it is listed in `labs/README.md`.

But **`plan/phase2-secrets-data-networking.md` never sequences it** — not the note, not the lab, not the objective id. A learner following the plan day-by-day never encounters it. Because the readiness gate (`plan/review.md`, `assessment/readiness.md`) requires **every** tracker objective green ("notes read, its lab performed or walkthrough studied, confidence ≥ 2"), the plan as written **cannot produce a green tracker** — a coherence gap between the plan (the declared spine) and the tracker (the declared source of truth).

The lab itself is self-contained and followable (CI-validated reference, explicit `kind delete`/recreate to swap kindnet→Cilium, eBPF/Lima caveat), so this is a *sequencing/coherence* decision, not a broken lab. It does, however, introduce heavy new concepts (eBPF CNI replacing kindnet, Egress Gateway, FQDN policy + host firewall, Hubble, Cluster Mesh) that warrant real day-time if included.

## What Changes

Pick one and make the plan and tracker agree:

- **(A) Sequence it into Phase 2.** Add a study day (or a clearly-scoped block) in `plan/phase2-secrets-data-networking.md` for `d2-fabric`, budget its footprint in the resource table, and note the CNI swap requires recreating the cluster (so schedule it where that won't disrupt other Day work). **or**
- **(B) Explicitly de-scope it.** Mark `d2-fabric` optional/beyond-plan in `tracker.yaml` and the labs catalog, and exclude it from the readiness gate so a learner can reach a green tracker without it (while keeping the lab available as enrichment).

Add a guardrail requirement so future tracked objectives can't silently become orphaned.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `study-schedule` — adds a requirement that every tracked objective is either sequenced into a plan phase day or explicitly marked optional and excluded from the readiness gate, so the plan can always produce a green tracker.

## Impact

- Affected specs: `study-schedule` (one ADDED requirement).
- Affected content (at implementation time): `plan/phase2-secrets-data-networking.md` and/or `assessment/data/tracker.yaml` + `assessment/readiness.md` + `labs/README.md`, depending on option A vs B.
- Resolves the plan-vs-tracker coherence gap for `d2-fabric` (`fab-*`).
