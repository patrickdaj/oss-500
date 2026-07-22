## Why

study-hub's Plan pages render only phases 0–4 + review because the `plan/` directory was never extended when the two "beyond-blueprint" tracks were added. Labs (`d5-*`, `d6-*`), domain notes (`5-offensive-validation/`, `6-agentic-zero-trust/`), and the tracker (domains `d5`, `d6`) all carry this content and render correctly — but a learner following the plan never sees a path through offensive validation or agentic zero trust. The plan is the spine of the curriculum; leaving 5/6 off it makes the two newest domains effectively invisible to anyone studying by the plan.

## What Changes

- Add `plan/phase5-offensive-validation.md` — a day-structured phase covering the four Domain 5 subsections (purple-team method, AI red-teaming, infra attack simulation, ZTNA authorization testing) using the existing phase-file format that study-hub parses into checkable blocks.
- Add `plan/phase6-agentic-zero-trust.md` — a day-structured phase covering the five Domain 6 subsections (agent delegated identity, tool/MCP trust boundaries, autonomous-action gating, multi-agent trust, red-team the agent).
- Update `plan/overview.md`: extend the phase-map table (add rows 5 and 6 before Review), the resource-readiness table, and correct the "six phases" framing to reflect the two additional beyond-blueprint phases.
- Both new phases are **beyond-blueprint** (no SC-500 exam weight), but are gated as first-class peers of phases 1–4: each ends on its domain checkpoint (`checkpoint-5`/`checkpoint-6`, added by the sibling `add-checkpoints-tracks-5-6` change), with a below-bar score routing the synthesis day to remediation. Proof-of-work — the technique fires and its detection/authorization/gating outcome is confirmed — remains the per-lab observable, distinct from the checkpoint phase gate.

No study-hub code change is required: its adapter globs `plan/*.md`, filters on `/(phase\d|review)/`, and derives order from `phase(\d+)`, so `phase5-*`/`phase6-*` render automatically once authored. The study-hub `content/oss-500` submodule pointer must be advanced to the commit carrying these files (out-of-repo follow-up, noted in tasks).

## Capabilities

### New Capabilities
<!-- None. The phased plan under plan/ is already the study-schedule capability; this extends it. -->

### Modified Capabilities
- `study-schedule`: the phased path is extended with beyond-blueprint phases 5 and 6 (day-structured, parseable, sequenced after the SC-500 domains and before review), each gating on its domain checkpoint. Sequenced after `add-checkpoints-tracks-5-6`, which provides those checkpoint banks.

## Impact

- **Content**: `plan/phase5-offensive-validation.md` (new), `plan/phase6-agentic-zero-trust.md` (new), `plan/overview.md` (edited).
- **References**: new plan files link into existing `domains/5-offensive-validation/*`, `domains/6-agentic-zero-trust/*`, `labs/d5-*`, `labs/d6-*`, and `lab-infra/*` — link targets must resolve (checked by `npm run lint:links`).
- **Rendering**: study-hub Plan view gains phases 5 and 6 automatically; no code change. Submodule pointer bump is a downstream step.
- **No breaking changes**: purely additive to plan content.
