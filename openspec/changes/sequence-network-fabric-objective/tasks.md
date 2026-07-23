# Tasks — sequence-network-fabric-objective

## 1. Decide (design)

- [x] 1.1 **Chosen: (A) sequence `d2-fabric` into Phase 2.**

## 2a. Option A — sequence it

- [x] 2a.1 Added **Day 7 — Cloud network fabric (Cilium)** in `plan/phase2-secrets-data-networking.md` referencing `network-fabric.md` and `labs/d2-network-fabric.md` (read + Parts A–E); flex/checkpoint moved to Day 8.
- [x] 2a.2 Added the fabric footprint + the cluster-rebuild caveat to the Phase 2 resource plan; placed the day **last** so the kindnet→Cilium swap doesn't strand other labs, with an explicit recreate-standard-cluster step before Phase 3.

## 2b. Option B — de-scope it

- [x] 2b.1 N/A — option A chosen; `d2-fabric` stays gate-required and is now reachable through the plan.
- [x] 2b.2 N/A — option A chosen.

## 3. Guardrail + regen

- [x] 3.1 The `study-schedule` guardrail (this change's spec delta) is in place so no future tracked objective is left both unsequenced and gate-required.
- [x] 3.2 No tracker YAML change (sequenced, not marked optional) → no `gen:md` needed.

## 4. Validation

- [x] 4.1 Cross-check re-run: `d2-fabric` and all five `fab-*` subsections now appear in `plan/` (previously fully absent). Remaining not-in-plan ids are group-level ids and the known id-citation NIT, not orphans.
- [x] 4.2 `npm run lint:links` OK; `npx openspec validate sequence-network-fabric-objective --strict` passes.
