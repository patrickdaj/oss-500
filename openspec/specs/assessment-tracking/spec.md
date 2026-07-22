# assessment-tracking Specification

## Purpose

OSS-500 has to make exam readiness verifiable, not merely aspirational. This capability defines how readiness is tracked objective-by-objective: a coverage tracker generated from a machine-readable source, per-domain checkpoint quizzes authored to the OSS stack, and a self-readiness gate with a remediation loop that maps every missed question back to a tracker row.
## Requirements
### Requirement: Objective coverage tracker
The repo SHALL contain a tracker at `assessment/tracker.md` (generated from `assessment/data/tracker.yaml`) listing every SC-500 objective bullet with columns for: notes done, resources done, lab done (hands-on vs walkthrough), checkpoint passed, and confidence (1–3) — so readiness is verifiable objective-by-objective.

#### Scenario: Tracker completeness
- **WHEN** the tracker is compared against the official SC-500 study-guide outline
- **THEN** every outline bullet appears exactly once, and each row exposes all five status columns

#### Scenario: Gaps are visible
- **WHEN** any row lacks a completed lab or has confidence 1
- **THEN** it is identifiable by simple inspection (or grep) as a remediation target for the review phase

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

### Requirement: Readiness gate
The assessment section SHALL define a self-readiness rule under `assessment/readiness.md` — a target checkpoint score across all six checkpoint banks plus completion of the full-stack capstone — with a remediation loop where every missed question maps back to a tracker row.

#### Scenario: Gate enforcement
- **WHEN** a checkpoint attempt scores below the readiness target
- **THEN** the process directs logging missed objectives in the tracker and repeating remediation before declaring readiness

#### Scenario: Gate spans all domains
- **WHEN** a reader opens `assessment/readiness.md`
- **THEN** the checkpoint condition lists all six banks (checkpoint-1 through checkpoint-6), including the beyond-blueprint domains

