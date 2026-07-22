## Context

`plan/` was authored around SC-500's exam blueprint: phase 0 (fundamentals ramp) + phases 1–4 (the four exam domains, weighted) + review. Two beyond-blueprint tracks were later added everywhere *except* the plan — domain notes (`domains/5-offensive-validation/`, `domains/6-agentic-zero-trust/`), labs (`labs/d5-*`, `labs/d6-*`), lab-infra, and the tracker (`d5`, `d6`) all carry them. study-hub renders oss-500 as a git submodule pinned at the latest commit (`8c3af33`), which contains all of that — so 5/6 already appear in Labs and Notes, but not in Plan, because no `phase5`/`phase6` file exists.

study-hub's oss-500 adapter globs `content/*/plan/*.md`, keeps files matching `/(phase\d|review)/`, and derives display order from `phase(\d+)` (review sorts last). So authoring `plan/phase5-*.md` and `plan/phase6-*.md` in the existing format is sufficient — no app code changes.

The two new domains are `weight: beyond-blueprint` (no SC-500 exam percentage), but the sibling `add-checkpoints-tracks-5-6` change adds `quiz-5.yaml`/`quiz-6.yaml`, so phases 5/6 gate on their checkpoint exactly as phases 1–4 do. This change is sequenced after that one.

## Goals / Non-Goals

**Goals:**
- Give phases 5 and 6 a day-structured plan file in the format study-hub already parses, covering every subsection of tracker domains `d5` and `d6`, linking real notes/labs/lab-infra.
- Keep `plan/overview.md` (phase map, resource table, framing) consistent with the added phases.
- Gate phases 5/6 on their domain checkpoint (`checkpoint-5`/`checkpoint-6`) like phases 1–4, with proof-of-work retained as the per-lab observable.

**Non-Goals:**
- No study-hub code changes.
- Authoring the `quiz-5`/`quiz-6` banks themselves — owned by the sibling `add-checkpoints-tracks-5-6` change; this change only references the checkpoints.
- No rewrite of phases 0–4 or the domain notes/labs themselves.
- Advancing the study-hub submodule pointer is a downstream operational step, tracked but performed in the study-hub repo, not here.

## Decisions

**Mirror the existing phase-file anatomy exactly.** Each new file opens with an H1 `# Phase N — <title>`, an intro paragraph (domain weight framing → but stated as *beyond-blueprint*), a "where things live" sentence pointing at the domain notes/labs/lab-infra, then `## Day N — <focus>` sections of `- [ ] **[Xh] <block>** — <details>` items, closing with a milestone section. This matches `phase4-posture-monitoring.md` and guarantees the parser produces checkable blocks. Alternative considered: a leaner format — rejected because study-hub's parser and the learner's muscle memory both depend on the established shape.

**Day allocation from subsections.** Domain 5 has 4 subsections (purple-team method, AI red-teaming [garak+pyrit], infra attack sim [atomic+caldera/stratus], ZTNA authz); domain 6 has 5 (agent identity, tool/MCP boundaries, action gating, multi-agent trust, red-team the agent). Map roughly one focus-area per day, with the purple-team *method* front-loaded as day 1 of phase 5 since it frames every later lab ("name the technique, fire it, confirm detection"). Phase 5 ≈ 4 days + a synthesis/flex day; phase 6 ≈ 5 days + a synthesis day. Each day ends with the lab's confirm-the-control observable.

**Two milestones: per-lab proof-of-work + a phase-gating checkpoint.** Each day's lab closes on a demonstrated outcome (e.g. "garak flags a jailbreak the guardrail missed and you close it"; "an over-scoped agent action is paused at the gate and denied"). The phase's final day then directs taking `checkpoint-5`/`checkpoint-6` in test mode, with a below-bar score routing the synthesis day to remediation — identical wiring to phases 1–4. Alternative considered: proof-of-work only, no checkpoint — rejected once the beyond-blueprint tracks were promoted to first-class gated peers (see `add-checkpoints-tracks-5-6`).

**Overview edits, minimal and surgical.** Add two rows to the phase-map table (between phase 4 and Review) with an em-dash exam-weight cell and a proof-of-work milestone; add two rows to the resource-readiness table (5/6 footprints are light — attack tooling + the already-running detection/identity stacks they target); fix the intro sentence that enumerates phases so it no longer says "six phases" exclusively. Keep review row last.

## Risks / Trade-offs

- **Broken links** → every note/lab/lab-infra path is copied from verified tracker/dir listings and validated with `npm run lint:links` before done.
- **Resource-table accuracy** → 5/6 labs mostly *reuse* stacks stood up in earlier phases (SIEM/observability for detection confirmation, identity for agent SVIDs); the table will state "reuses Phase 3/4 stacks + attack tooling" rather than invent new footprints, and mark anything host-constrained as walkthrough, consistent with existing rows.
- **Stale study-hub view** → files land in oss-500 but study-hub reads a pinned submodule commit; until the pointer is advanced, Plan still shows 0–4. Mitigated by an explicit submodule-bump task and a verification step that loads study-hub after the bump.
- **Day-count guess** → the per-day split is an estimate; the last day of each phase is flex/synthesis so slippage is absorbed, matching the plan's existing convention.

## Migration Plan

1. Author `plan/phase5-offensive-validation.md` and `plan/phase6-agentic-zero-trust.md`; edit `plan/overview.md`.
2. `npm run lint:links` in oss-500 → all links resolve.
3. Commit in oss-500.
4. In study-hub: advance `content/oss-500` submodule to the new commit, `git add content/oss-500`, commit; run the app and confirm Plan lists phases 5 and 6 with checkable blocks.

Rollback: revert the oss-500 commit (purely additive content) and the submodule bump; no data or schema migration involved.

## Open Questions

- Exact day counts (phase 5 ≈ 5 days incl. flex, phase 6 ≈ 6 days incl. synthesis) — resolved during authoring against per-subsection lab depth; not blocking.
