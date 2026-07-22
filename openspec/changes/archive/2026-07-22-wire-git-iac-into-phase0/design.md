## Context

The git + Terraform ramp note (`domains/0-fundamentals/05-git-iac-foundation.md`) was added by `add-git-iac-foundation` with an explicit "no tracker/objective change" and only a cross-link from `03-kind-helm-iac.md`. It never entered `plan/phase0-fundamentals.md`, so the study path — the surface a learner actually navigates — never points at it. The note itself states it is "the foundation underneath" `03-kind-helm-iac.md` and should be read "before the automated labs."

## Goals / Non-Goals

**Goals:**
- Surface `05-git-iac-foundation.md` on the Phase-0 study path so it precedes the applied kind/Helm/IaC work.
- Make the link durable and lint-covered so a future plan edit can't silently re-orphan it.
- Reinforce the note's own self-check at the phase level.

**Non-Goals:**
- No new domain content; the note already exists and is complete.
- No tracker/objective/exam-weight change — Phase 0 is a ramp with no checkpoint gate.
- Not reconciling the pre-existing "k3s" vs actual `kind` wording in the spec/plan; out of scope here.

## Decisions

- **Home it on Day 3, as a leading reading block.** Day 3 is "kind cluster, Helm, and the IaC loop" — the exact applied work the note underpins. A block placed before the "Stand up the lab cluster" block matches the note's "read the foundation first" framing. Alternative considered: a new standalone day — rejected as overweight for a ramp note with no lab of its own. Alternative: Day 4 flex — rejected because that lands the foundation *after* the IaC loop it's meant to precede.
- **Add one self-check item** mirroring the note (git working-tree/index/repo model; Terraform state + locking) so the phase self-check exercises what the reading taught.
- **Encode it as a `study-schedule` delta**, not a bare edit, so the requirement (and `lint:links`) keep the link alive. A new dedicated scenario makes the link independently testable rather than folding it into the existing ramp scenario's prose.

## Risks / Trade-offs

- [Day 3 already sums to its target hours] → The reading block is small (~0.5h) and the note is short; add it without inflating Day 3 past a reasonable budget, trimming block phrasing rather than adding a full hour.
- [Link could drift if the note is renamed] → `npm run lint:links` fails on a broken path, and the new scenario names the exact file, so drift surfaces at lint/verify time.
