# Ship garak/PyRIT scaffolding for the AI red-team labs

## Why

Two tracks require LLM red-team tooling with no scaffolding: `d5-ai-redteam` and `d6-validate` both say "script a multi-turn PyRIT orchestrator" backed by only a GitHub link, and the garak REST-generator JSON format (`-G localhost-ollama.json`) that points garak at the local Ollama gateway is never shown (audit Part 4.4, line 120). For the persona's stated weak spot — LLM red-team tooling — these are "leave the curriculum and reverse-engineer the tool" tasks despite strong Python. One reference-solution command line partly rescues garak; PyRIT gets nothing.

## What Changes

- Ship a **~20-line PyRIT orchestrator skeleton** in `lab-infra/offense/` (multi-turn orchestrator wired to the local Ollama/gateway target), referenced from the `d5-ai-redteam` and `d6-validate` notes as the starting point the learner extends.
- Ship a **working garak generator-config example** (`localhost-ollama.json` for the REST generator) in `lab-infra/offense/`, so `garak -G localhost-ollama.json …` runs against the local stack out of the box, referenced from the same notes.
- Keep both as *scaffolds the learner extends*, not finished answers — consistent with the course's "prove the control, don't just deploy the tool" and honest-results stance.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `lab-infrastructure` — adds a requirement that the AI red-team labs ship runnable offense scaffolding under `lab-infra/offense/` (a PyRIT orchestrator skeleton and a garak generator config) that targets the local gateway/Ollama out of the box.
- `offensive-validation` — adds a requirement that the AI-track validation labs (`d5-ai-redteam`, `d6-validate`) reference that shipped scaffolding as the starting point, rather than sending the learner to a bare tool repo.

## Impact

- Affected specs: `lab-infrastructure` (ADDED requirement) and `offensive-validation` (ADDED requirement).
- Affected content (at implementation time): new `lab-infra/offense/` files (PyRIT orchestrator skeleton, garak `localhost-ollama.json`); the `d5-ai-redteam` and `d6-validate` notes reference them and tag the tool docs by necessity.
- Removes the two "leave-the-curriculum" tasks for the persona's weakest declared area.
