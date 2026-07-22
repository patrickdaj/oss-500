## Context

Checkpoint quizzes live at `assessment/data/quiz-<n>.yaml` and drive three consumers with zero course-specific code: study-hub globs `assessment/data/*.yaml`, keeps `quiz-\d+\.yaml`, and maps each into its `Quiz` model (`domain` → `domains[]`); `scripts/gen-md.mjs` globs the same pattern and emits `assessment/checkpoint-<n>.md`; and `assessment/readiness.md` links the checkpoint docs as the gate. Domains `d1`–`d4` each have a bank (28/40/28/31 questions); `d5` and `d6` have none.

The quiz schema is fixed by the `study-data-format` spec: `id`, `title`, `domain`, `passPercent`, and `questions[]` where each has a unique `id`, `stem`, `options[]` (≥2), `type` (`single`|`multi`), zero-based `answer` index(es), `explanation`, `docUrl`, and `objectiveIds[]` resolving to tracker ids. No schema change is needed — only two new conforming files.

Domain 5 objectives: `pt-method`, `av-ai-garak`, `av-ai-pyrit`, `av-atomic`, `av-caldera-stratus`, `av-ztna-authz` (4 subsections). Domain 6: `agent-workload`, `agent-deleg`, `mcp-authz`, `mcp-authn`, `action-gate`, `agent-mtls`, `agent-cascade`, `av-agent-actions` (5 subsections).

## Goals / Non-Goals

**Goals:**
- Author `quiz-5.yaml` and `quiz-6.yaml` as first-class banks conforming to the quiz model, grounded in the domain 5/6 notes, covering every objective.
- Regenerate checkpoint docs and extend the readiness gate to six banks.
- Reconcile the sibling plan change so phases 5/6 gate on these checkpoints.

**Non-Goals:**
- No study-hub code changes; no quiz-schema changes.
- No rewrite of `d1`–`d4` banks or of the domain 5/6 notes/labs.
- No change to the capstone definition (identity→workload→detection→SIEM chain); 5/6 are added as checkpoint banks, not capstone stages.
- Submodule pointer bump is performed in the study-hub repo, tracked but not owned here.

## Decisions

**Follow the existing bank anatomy exactly.** Header comment citing the source notes and the zero-based-answer convention; `id: quiz-5`/`quiz-6`; `title: "Checkpoint 5 — Prove it: offensive validation"` / `"Checkpoint 6 — Agentic zero trust"`; `domain: d5`/`d6`; `passPercent: 80`. Question ids `q5-01…` / `q6-01…`. This matches `quiz-4.yaml` and keeps study-hub's validator and `gen-md.mjs` happy. Alternative considered: a leaner format for beyond-blueprint banks — rejected; divergence would break the shared validator and reader expectations.

**Question count and coverage.** ~18–20 per bank (chosen), floored at 18 per the modified spec. Allocate proportionally so every objective is represented by at least one question and the higher-surface subsections (AI red-teaming, MCP trust boundaries, action gating) get two. Favor scenario stems that force the *distinction the domain teaches* (e.g. workload SVID vs. scoped on-behalf-of token; authorize-every-call vs. authenticate-every-caller; pause-consequence gating vs. blanket allow) rather than tool trivia — mirroring how `quiz-4` tests concepts, not commands.

**Pass bar stays 80%, readiness stays 85%×2.** `passPercent: 80` per bank matches the other banks; the readiness gate's stricter "≥85% on two consecutive attempts" is a `readiness.md` rule and simply gains checkpoint-5/6 in its list. Keeping both bars identical to the SC-500 banks is what "first-class gate" means.

**Reconcile the plan change rather than duplicate.** `add-plan-tracks-5-6` currently declares "no checkpoint (proof-of-work milestone)" and introduces a new `study-plan` capability. Both become wrong once banks exist. This change's tasks include editing that change so: (a) phases 5/6 end on `checkpoint-5`/`checkpoint-6` with the same remediation routing as 1–4 (proof-of-work stays as the *lab* observable, the checkpoint becomes the *phase gate*); (b) its plan-side delta targets the existing `study-schedule` capability as an ADDED requirement for beyond-blueprint phases, dropping the phantom `study-plan` spec. Alternative considered: leave the plan change as-is and let it contradict this one — rejected; two unapplied changes must be coherent before either is applied.

## Risks / Trade-offs

- **Dangling objectiveIds / out-of-range answers** → author against the enumerated `d5`/`d6` ids and verify with study-hub `lint:content`; `gen:md` also fails loudly on malformed YAML.
- **Question quality drifting into tool trivia** → stems are written from the notes' core distinctions with a doc link per answer, reviewed against the `quiz-4` bar before done.
- **Readiness capstone mismatch** → the capstone remains the SC-500 control chain; 5/6 are self-assessment gates, so the gate text must not imply the capstone itself now covers offensive/agentic content. Mitigated by editing only the checkpoint list, not the capstone clause.
- **Stale study-hub view** → banks land in oss-500 but study-hub reads a pinned submodule; until the pointer advances, Tests shows four banks. Mitigated by an explicit submodule-bump + verify task.
- **Order-of-apply coupling** → if the plan change applies before this one, phases 5/6 would link not-yet-existing checkpoint docs. Mitigated by applying this assessment change first (or together) and by `lint:links` catching the gap.

## Migration Plan

1. Author `assessment/data/quiz-5.yaml` and `quiz-6.yaml`; run `npm run gen:md` to emit `checkpoint-5.md`/`checkpoint-6.md`.
2. Edit `assessment/readiness.md` to list all six banks.
3. Reconcile `add-plan-tracks-5-6` (proposal/specs/design/tasks) to gate phases 5/6 on their checkpoints and target `study-schedule`.
4. Validate: study-hub `lint:content` (objectiveIds/answers), `npm run lint:links` (readiness links), `openspec validate` both changes.
5. Commit in oss-500; advance the study-hub `content/oss-500` submodule, run the app, confirm six banks on the Tests page and both checkpoints reachable from readiness.

Rollback: revert the oss-500 commit and the submodule bump; additive content, no data migration.

## Open Questions

- Final per-objective question distribution (which subsections get two) — resolved during authoring against note depth; not blocking.
