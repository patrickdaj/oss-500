## Why

The tracker carries two beyond-blueprint domains — `d5` (offensive validation) and `d6` (agentic zero trust) — with full notes and labs, but neither has a checkpoint quiz bank. Every SC-500 domain (`d1`–`d4`) has one; 5 and 6 are the only domains a learner cannot self-assess or gate on. Promoting them to first-class peers of the exam domains means giving them the same checkpoint machinery: a scenario-based bank, a generated checkpoint doc, phase gating, and a place in the readiness gate.

## What Changes

- Add `assessment/data/quiz-5.yaml` (domain `d5`, ~18–20 scenario questions) and `assessment/data/quiz-6.yaml` (domain `d6`, ~18–20 questions), authored to the OSS stack from the domain 5/6 notes, each question carrying `objectiveIds` that resolve to real `d5`/`d6` tracker ids, a zero-based `answer`, an `explanation`, and an authoritative `docUrl`.
- Generate `assessment/checkpoint-5.md` and `assessment/checkpoint-6.md` via `npm run gen:md` (the generator already globs `quiz-\d+\.yaml`).
- Update `assessment/readiness.md`: the gate now spans **all six** checkpoint banks (add checkpoint-5 and checkpoint-6 to the list), keeping the existing ≥85%-twice rule.
- **First-class gating**: because 5/6 now have banks, phases 5 and 6 end on their checkpoint exactly like phases 1–4 (that phase-plan wiring lands in the sibling `add-plan-tracks-5-6` change, which this change reconciles — see Impact).

No study-hub code change: its adapter auto-discovers `quiz-N.yaml` into the Tests/Dashboard, and `gen-md.mjs` auto-generates the checkpoint docs. The study-hub `content/oss-500` submodule pointer must advance to the commit carrying these files (downstream step, in tasks).

## Capabilities

### New Capabilities
<!-- None. Checkpoints already exist as a capability; this extends its scope. -->

### Modified Capabilities
- `assessment-tracking`: the per-domain checkpoint-quiz requirement extends from the four SC-500 domains to every tracker domain, with a lower question floor for beyond-blueprint domains (≥18 vs ≥25); the readiness gate spans all six banks instead of four.

## Impact

- **Content**: `assessment/data/quiz-5.yaml`, `assessment/data/quiz-6.yaml` (new); `assessment/checkpoint-5.md`, `assessment/checkpoint-6.md` (generated); `assessment/readiness.md` (edited).
- **Cross-change reconciliation**: `add-plan-tracks-5-6` currently states phases 5/6 have no checkpoint (proof-of-work only). Since checkpoints will now exist, that change is updated so phases 5/6 gate on `checkpoint-5`/`checkpoint-6`, and its plan-side capability is corrected to modify `study-schedule` rather than a separate `study-plan` capability. Both changes are unapplied, so this is edit-time coordination, not a migration.
- **Validation**: every `objectiveIds` entry must resolve to a `tracker.yaml` id and every `answer` index must be in range (study-hub `lint:content` / the quiz model); links in `readiness.md` must resolve (`npm run lint:links`).
- **Rendering**: study-hub Tests page and Dashboard gain two banks automatically; submodule pointer bump is the downstream step.
- **No breaking changes**: additive banks + an extended gate.
