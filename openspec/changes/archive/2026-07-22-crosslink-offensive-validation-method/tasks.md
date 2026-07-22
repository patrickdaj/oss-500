# Tasks — crosslink-offensive-validation-method

## 1. Back-link the D6 applier to the canonical method

- [x] 1.1 In `domains/6-agentic-zero-trust/d6-validate.md`, above or within the "## Method (the four steps, agent flavor)" section (lines ~22–26), add a back-link naming `purple-team.md` as the canonical method — e.g. "The four steps are defined canonically in [`purple-team.md`](../5-offensive-validation/purple-team.md); here in agent flavor:". Keep the existing agent-flavored numbered list as the note's own reinforcement.
- [x] 1.2 Confirm the existing `d5-ai-redteam` boundary link (line 5) is left intact — it serves a different purpose (surface contrast), not the method reference.

## 2. (Optional) Point the D5 flavor headers at the canonical method

- [x] 2.1 In `domains/5-offensive-validation/ai-redteam.md`, `infra-attack-simulation.md`, and `ztna-authz.md`, have each "## Method (the four steps, … flavor)" header reference the canonical method (e.g. "as defined in [`purple-team.md`](purple-team.md)"). These are already legitimate `purple-team.md` children; this only makes the single-source-of-truth explicit. Do not remove any flavored steps.

## 3. Out of scope (tracking only)

- [x] 3.1 Do **not** trim the quiz-5 method-cluster near-duplicate here — it is handled by the separate `dedup-quiz-question-intent` change. (Note only; no edit.)

## 4. Validation

- [x] 4.1 Run `npm run lint:links` and confirm the new relative link(s) resolve and no links broke.
- [x] 4.2 Run `openspec validate crosslink-offensive-validation-method --strict` and confirm it passes.
