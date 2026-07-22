## Why

`domains/0-fundamentals/05-git-iac-foundation.md` (the git + Terraform ramp note) exists and is cross-linked only from `03-kind-helm-iac.md` — it is never referenced from `plan/phase0-fundamentals.md`, so a learner following the study path never encounters it. The foundation the automated ZTNA labs and `gov-iac` assume is effectively invisible.

## What Changes

- Add a leading reading block to **Day 3** of `plan/phase0-fundamentals.md` that directs reading `05-git-iac-foundation.md` (git model + Terraform write→plan→apply) *before* the applied kind/Helm work, matching the note's own "foundation underneath `03-kind-helm-iac.md`" framing.
- Add a Phase-0 self-check item covering the git working-tree/index/repo model and Terraform state/locking, mirroring the note's self-check.
- Strengthen the `study-schedule` "Fundamentals ramp precedes security content" requirement so the Phase-0 plan is required to link the git + Terraform (IaC) foundation note, keeping the link durable under `lint:links`.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `study-schedule`: the "Fundamentals ramp precedes security content" requirement adds that the Phase-0 plan links a git + Terraform (IaC) foundation note, not just Helm and the kind/IaC loop.

## Impact

- `plan/phase0-fundamentals.md` — Day 3 reading block + self-check item.
- `openspec/specs/study-schedule/spec.md` — synced on archive from this change's delta.
- No change to `assessment/data/tracker.yaml` (ramp, no exam objective); no code changes. Validated by `npm run lint:links` and `openspec validate`.
