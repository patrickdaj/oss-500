## ADDED Requirements

### Requirement: AI-track validation labs reference the shipped offense scaffolding

The AI-track validation labs (`d5-ai-redteam` and `d6-validate`) SHALL reference the shipped `lab-infra/offense/` scaffolding — the PyRIT orchestrator skeleton and the garak generator config — as the starting point the learner extends, rather than sending the learner to a bare tool repository with no runnable starting artifact. Where a lab asks the learner to "script a multi-turn PyRIT orchestrator" or run garak against the local gateway, it SHALL point at the shipped skeleton/config and mark the tool documentation by necessity per the citation standard.

#### Scenario: The PyRIT task starts from shipped scaffolding

- **WHEN** a learner reaches the "script a multi-turn PyRIT orchestrator" step in `d5-ai-redteam` or `d6-validate`
- **THEN** the lab points at the shipped `lab-infra/offense/` PyRIT skeleton as the starting point to extend, not a bare GitHub link

#### Scenario: The garak task uses the shipped generator config

- **WHEN** a learner runs garak against the local gateway in an AI-track validation lab
- **THEN** the lab references the shipped `localhost-ollama.json` generator config, so the learner does not have to author the REST-generator JSON from scratch
