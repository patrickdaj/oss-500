## 1. Checkpoint 5 — offensive validation

- [x] 1.1 Read the domain 5 notes for authoring source: `domains/5-offensive-validation/purple-team.md`, `ai-redteam.md`, `infra-attack-simulation.md`, `ztna-authz.md`.
- [x] 1.2 Create `assessment/data/quiz-5.yaml` header: `id: quiz-5`, `title: "Checkpoint 5 — Prove it: offensive validation"`, `domain: d5`, `passPercent: 80`, plus the source-notes/zero-based-answer comment matching `quiz-4.yaml`.
- [x] 1.3 Author ~18–20 scenario questions (`q5-01…`) covering every d5 objective — `pt-method`, `av-ai-garak`, `av-ai-pyrit`, `av-atomic`, `av-caldera-stratus`, `av-ztna-authz` — each with `objectiveIds`, `type`, `options` (≥2), zero-based `answer`, `explanation`, and a `docUrl`. Give AI red-teaming and infra attack sim two questions each; stems test the domain's core distinctions (name-the-technique → fire → confirm detection), not tool trivia.

## 2. Checkpoint 6 — agentic zero trust

- [x] 2.1 Read the domain 6 notes: `domains/6-agentic-zero-trust/d6-identity.md`, `d6-tools-mcp.md`, `d6-action-gating.md`, `d6-multi-agent.md`, `d6-validate.md`.
- [x] 2.2 Create `assessment/data/quiz-6.yaml` header: `id: quiz-6`, `title: "Checkpoint 6 — Agentic zero trust"`, `domain: d6`, `passPercent: 80`, matching comment convention.
- [x] 2.3 Author ~18–20 scenario questions (`q6-01…`) covering every d6 objective — `agent-workload`, `agent-deleg`, `mcp-authz`, `mcp-authn`, `action-gate`, `agent-mtls`, `agent-cascade`, `av-agent-actions` — each fully formed. Stems force the taught distinctions (workload SVID vs. scoped OBO token; authorize-every-call vs. authenticate-every-caller; pause-consequence gating; no privilege laundering).

## 3. Generate + readiness gate

- [x] 3.1 Run `npm run gen:md`; confirm it emits `assessment/checkpoint-5.md` and `assessment/checkpoint-6.md`.
- [x] 3.2 Edit `assessment/readiness.md`: add checkpoint-5 and checkpoint-6 to the Checkpoints list (now six banks); keep the ≥85%-twice rule and the capstone clause unchanged.

## 4. Plan-change coherence (reconciled at proposal time)

The sibling `add-plan-tracks-5-6` was already updated during this proposal so phases 5/6 gate on `checkpoint-5`/`checkpoint-6` and its plan-side delta targets `study-schedule` (not a `study-plan` capability). These tasks only re-verify that coherence still holds at apply time.

- [x] 4.1 Confirm `add-plan-tracks-5-6` has no residual "no checkpoint" language and its final-day tasks (1.6, 2.7) direct taking checkpoint-5/6.
- [x] 4.2 `openspec validate add-checkpoints-tracks-5-6` and `openspec validate add-plan-tracks-5-6` both pass.

## 5. Verify

- [ ] 5.1 study-hub `lint:content` passes: every `objectiveIds` resolves to a tracker id and every `answer` index is in range for the new banks.
- [x] 5.2 `npm run lint:links` passes for edited `assessment/readiness.md`.
- [ ] 5.3 Commit in oss-500. Advance the study-hub `content/oss-500` submodule to the new commit, `git add content/oss-500`, commit, run the app, and confirm six banks on the Tests page/Dashboard and both new checkpoints reachable from the readiness gate.
