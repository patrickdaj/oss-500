## Context

`plan/phase0-fundamentals.md` is the entry surface that routes a learner through Phase 0. It links five of the six notes in `domains/0-fundamentals/` (`00-linux-cli`, `01-containers`, `02-kubernetes`, `03-kind-helm-iac`, `05-git-iac-foundation`) but not `04-linux-networking.md`.

`04-linux-networking.md` was authored as a just-in-time substrate read for Phase 2's cloud-network-fabric work: it opens with "Read this before `network-fabric.md` and the `d2-network-fabric` lab," carries no exam objective, and is already linked from `plan/phase2-secrets-data-networking.md`, `domains/2-secrets-data-networking/network-fabric.md`, and `labs/d2-network-fabric.md`. It lives under `domains/0-fundamentals/` only because that is where the substrate-primitives notes sit; study-hub's loader surfaces every file in that directory as Phase 0 reading. So the note is structurally Phase 0 but pedagogically Phase 2, and the Phase 0 plan currently references it in neither role.

The chosen resolution (confirmed with the user) is the lightweight-pointer approach: acknowledge the note in Phase 0 as a forward reference, keep the deep read at its point of use in Phase 2. This closes the "silently skipped" gap while preserving the just-in-time pedagogy and the phase's time budget.

## Goals / Non-Goals

**Goals:**
- Make `domains/0-fundamentals/04-linux-networking.md` reachable from `plan/phase0-fundamentals.md`.
- State explicitly, at the pointer, that the deep read is scheduled in Phase 2 — so the learner knows it is a forward reference, not a Phase 0 study obligation.
- Keep the change small, content-only, and consistent with the existing plan's voice and link style.

**Non-Goals:**
- No full timed study block for the note; Phase 0's per-day hours and self-check are unchanged.
- No relocation or renumbering of the note, and no change to its existing Phase 2 links or to study-hub's loader.
- No duplication of the note's content into the plan; the pointer references, it does not restate.

## Decisions

- **Placement: Day 4 ("RBAC preview and flex").** Day 4 already holds the phase's forward-looking preview material (the Kubernetes RBAC preview that flags Phase 1's deep note) and has slack ("Catch-up / rest"). A networking read-ahead that points forward to Phase 2 matches that day's role better than Day 1, and adding it here does not disturb the Day 1–3 block timings. *Alternative considered:* attaching it to Day 1's Linux/CLI block, whose details already mention networking tools (`ss`, `ip`, `curl`, `dig`). Rejected because Day 1's note pointer is `00-linux-cli.md` and conflating the two invites the reader to treat `04` as required Day 1 reading — the opposite of the just-in-time intent.

- **Framing: forward reference, not a block.** The pointer is written as prose/preview text (mirroring the Day 4 RBAC-preview line that says "Phase 1's `kubernetes-rbac.md` goes deep"), not as a `- [ ] **[Nh]**` checkbox. This keeps it out of the parsed hour total and signals "optional read-ahead." *Alternative considered:* a zero-hour `[0h]` checkbox block. Rejected as a hack that still reads as a task and muddies progress roll-up.

- **Scope: single-file content edit.** The only file changed is `plan/phase0-fundamentals.md`. The spec delta records the new expectation on the existing `study-schedule` requirement (adds a scenario; no requirement-text or existing-scenario change), matching the precedent set by the git/Terraform-foundation-note scenario in the same requirement.

## Risks / Trade-offs

- [Reader treats the pointer as required Phase 0 reading, inflating perceived phase load] → Explicit "deep read in Phase 2" wording at the pointer, and placing it in the preview/flex day rather than a timed block.
- [Pointer wording drifts from the note's actual Phase 2 anchors if those links later move] → Reference the note by path and name it as the substrate for `network-fabric.md` / `d2-network-fabric`, matching the anchors the note itself already declares; if `lint:content` link-checks run, a stale path fails the lint.
- [Minor duplication of intent with Phase 2's existing link] → Acceptable and intentional: the two references serve different moments (forward-signpost in Phase 0 vs. point-of-use read in Phase 2), consistent with how the plan already signposts Phase 1's RBAC note from Phase 0.

## Migration Plan

Not applicable — additive documentation edit with no runtime, schema, route, or progress-tracking impact. Rollback is reverting the single-file diff.

## Open Questions

None.
