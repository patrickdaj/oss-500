# Tasks — add-garak-pyrit-scaffolding

## 1. Ship the scaffolding

- [ ] 1.1 Add a ~20-line PyRIT multi-turn orchestrator skeleton under `lab-infra/offense/`, wired to the local Ollama/gateway target and shaped as a starting point to extend.
- [ ] 1.2 Add a working garak generator config `lab-infra/offense/localhost-ollama.json` (REST generator) that points garak at the local gateway/Ollama.
- [ ] 1.3 Confirm both run against the local stack out of the box (`garak -G lab-infra/offense/localhost-ollama.json …`; PyRIT skeleton executes a minimal multi-turn run).

## 2. Reference from the notes

- [ ] 2.1 In `d5-ai-redteam` and `d6-validate`, point the "script a multi-turn PyRIT orchestrator" and garak steps at the shipped scaffolding.
- [ ] 2.2 Tag the PyRIT and garak tool docs by necessity per `rank-learning-references`.

## 3. Validation

- [ ] 3.1 Run `openspec validate add-garak-pyrit-scaffolding --type change --strict`.
