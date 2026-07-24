## ADDED Requirements

### Requirement: The AI red-team labs ship runnable offense scaffolding

`lab-infra/offense/` SHALL ship runnable scaffolding for the AI red-team tracks: a PyRIT multi-turn orchestrator skeleton wired to the local Ollama/gateway target, and a garak generator-config example (`localhost-ollama.json` for the REST generator) that points garak at the local stack. Both SHALL run against the local lab stack out of the box — `garak -G lab-infra/offense/localhost-ollama.json …` targets the local gateway without edits, and the PyRIT skeleton executes a minimal multi-turn run — and both SHALL be shaped as scaffolds the learner extends, not finished exploits.

#### Scenario: garak targets the local stack from the shipped config

- **WHEN** a learner runs garak with the shipped `-G localhost-ollama.json` generator config against the running AI gateway/Ollama
- **THEN** garak connects to the local target and runs, with no undocumented JSON the learner had to reverse-engineer from the garak docs

#### Scenario: The PyRIT skeleton runs a multi-turn orchestration

- **WHEN** a learner runs the shipped PyRIT orchestrator skeleton against the local target
- **THEN** it executes a minimal multi-turn orchestration the learner can extend, rather than starting from an empty file and a bare GitHub link
