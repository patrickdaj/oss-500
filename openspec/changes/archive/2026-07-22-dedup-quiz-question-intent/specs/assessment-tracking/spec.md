## MODIFIED Requirements

### Requirement: Per-domain checkpoint quizzes
Every domain in the tracker SHALL have an authored checkpoint quiz under `assessment/`, written to the concepts as expressed through the OSS stack (not copied from dumps), each question with the correct answer, an explanation, and a link to an authoritative doc. The four SC-500 domains SHALL have at least 25 scenario-style questions each; the beyond-blueprint domains (`d5` offensive validation, `d6` agentic zero trust) SHALL have at least 18 each, sized to their smaller objective set. Every question's `objectiveIds` SHALL resolve to ids in `assessment/data/tracker.yaml`.

#### Scenario: Quiz format
- **WHEN** a reader opens any checkpoint quiz
- **THEN** questions are scenario-based, answers are separated from questions (collapsible), and every answer includes an explanation with a doc link

#### Scenario: Every domain has a bank
- **WHEN** the set of `domains[].id` in `tracker.yaml` is compared to the `quiz-<n>.yaml` banks in `assessment/data/`
- **THEN** every domain — SC-500 and beyond-blueprint — has a corresponding bank, meeting its question floor (≥25 for `d1`–`d4`, ≥18 for `d5`–`d6`)

#### Scenario: Checkpoint gates the phase
- **WHEN** a domain phase ends
- **THEN** the plan directs taking that domain's checkpoint, and scores below the pass bar route the flex/synthesis day to remediation

#### Scenario: No two questions test the same intent
- **WHEN** the questions across all `quiz-<n>.yaml` banks are compared by intent (the idea a stem tests and its correct-answer takeaway), not merely by keyword
- **THEN** no two questions test the same intent — any duplicate is removed or repurposed to test the domain-specific delta assuming the fundamental, each reclaimed slot maps to an under-covered objective, and no domain drops below its question floor or loses coverage of an `objectiveIds` value it previously carried
