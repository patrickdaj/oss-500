## Why

`domains/0-fundamentals/04-linux-networking.md` is the only Phase 0 domain note that `plan/phase0-fundamentals.md` never links. The Phase 0 plan walks the learner through the other five notes (`00`, `01`, `02`, `03`, `05`) but silently skips `04`, so a fundamentals note is invisible from the plan surface that is meant to route the whole phase.

The note is authored as a **just-in-time read-ahead for Phase 2** — it says "Read this before `network-fabric.md`" and is correctly linked from `plan/phase2-secrets-data-networking.md`, `domains/2-secrets-data-networking/network-fabric.md`, and the `d2-network-fabric` lab. But because it physically lives in `domains/0-fundamentals/`, study-hub's loader surfaces it as Phase 0 content, and the Phase 0 plan accounts for it neither as a study block nor as a pointer. The result is a note that is structurally Phase 0 but pedagogically Phase 2, unreferenced by either phase's entry path except the deep Phase 2 links.

## What Changes

- `plan/phase0-fundamentals.md` SHALL add a **lightweight read-ahead pointer** to `domains/0-fundamentals/04-linux-networking.md`, naming it as the Linux-networking substrate note and stating that its **deep read is scheduled in Phase 2** (with `network-fabric.md` / the `d2-network-fabric` lab) — closing the "silently skipped" gap.
- The pointer is deliberately **not a full timed study block**: it does not add planned hours to Phase 0 and does not change the phase's day-by-day time budget. The just-in-time design (deep read at point-of-use in Phase 2) is preserved.
- The note is **not** relocated or renumbered, and its existing Phase 2 links are unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `study-schedule` — extends the "Phased learning path calibrated to SC-500 domain weights" requirement with a scenario asserting the Phase 0 plan points to the Linux-networking substrate note as a Phase 2 read-ahead, analogous to the existing scenario that links the git/Terraform foundation note. No change to the phase's time-budget or block-structure requirements.

## Impact

- Affected specs: `study-schedule` (one modified requirement — adds a scenario; no requirement text change).
- Affected content: `plan/phase0-fundamentals.md` (add the read-ahead pointer, likely on Day 4 alongside the RBAC/networking preview framing). No changes to `domains/0-fundamentals/04-linux-networking.md`, its Phase 2 links, the study-hub loader, or the phase self-check.
- Fixes: all six Phase 0 domain notes are now reachable from the Phase 0 plan.
