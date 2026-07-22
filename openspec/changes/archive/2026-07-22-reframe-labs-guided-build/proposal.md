## Why

OSS-500's labs teach well but **hand over the answer**: they explain the *why* and always land on a concrete prove-it observable (a denied request, a fired rule, a timeout) — the course's real strength — yet the complete artifact (full YAML, exact commands) sits inline, so there is no "you build it" moment and no reference solution to check against. Learning is in the building; a lab that hands the solution skips the productive struggle. Domain 6 was authored to the better pattern (guided build → a marked "Reference solution"), and it should be the norm, not the exception. This change retrofits the 28 existing labs (Domains 1–5) to that pattern.

## What Changes

- **A documented lab pedagogy** (`guided-lab-pedagogy`): every lab follows *challenge → guided build → verify → reference solution*. The learner is told what to achieve and the observable to reach, guided (hints, checkpoints, partial scaffolding, "your turn" prompts) to build it themselves, confirms the control holds, and only then checks a clearly-marked full solution. Codified once in `labs/README.md` (with the `d6-*` labs cited as the exemplar) so it holds for future labs.
- **Retrofit all 28 Domain 1–5 labs** to the template: the inline full solution is **relocated** out of the step-by-step flow into an end-of-lab **Reference solution** section (or a pointer to the `lab-infra/` component where the deployable artifact already lives), and the build steps become guided prompts that keep the strong "why" explanations but withhold the finished artifact until the learner has tried.
- **Preserve everything taught**: objective ids, SC-500 mappings, prove-it observables, `lab-infra` components, and tracker entries are unchanged. No solution content is deleted — only relocated and marked. This is a *how-it-teaches* reframe, not a content or accuracy change.

## Capabilities

### New Capabilities
- `guided-lab-pedagogy`: The curriculum's standard for how a lab teaches — a challenge and guided build that require the learner to produce the artifact and reach the observable themselves, backed by a preserved, clearly-marked reference solution — plus the retrofit of all Domain 1–5 labs to it.

### Modified Capabilities
<!-- The build-oss-500-course lab capabilities are not archived to openspec/specs/, so
     this change carries the pedagogy as a new capability. It relocates (never deletes)
     solution content and adds structure; objectives/observables/tracker are untouched. -->
- None (no archived specs to delta; objectives and observables unchanged).

## Impact

- **Content (bulk)**: all 28 labs under `labs/` for Domains 1–5 are restructured (`d1-*` … `d5-*`); `labs/README.md` gains the "how labs teach" convention. `d6-*` labs already comply and are the exemplar (left as-is or lightly aligned).
- **Possibly `lab-infra/`**: where extracting a solution artifact (a manifest/policy) into its component reads cleaner than an in-lab block, a few reference files may be added — no behavior change to any component.
- **No change** to `domains/**` notes, `assessment/data/tracker.yaml`, objective ids, SC-500 mappings, or lab-infra behavior. `lint:links` must stay green (relocated links still satisfy the `resource-citation` standard).
- **study-hub**: content *shape* (domain/objective counts, notes/lab paths) is unchanged, so its tests stay green; after the retrofit, bump the `content/oss-500` submodule and confirm `lint:content` + tests pass and the restructured labs render.
