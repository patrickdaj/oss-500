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
Each of the four SC-500 domains SHALL have an authored checkpoint quiz of at least 25 scenario-style questions under `assessment/`, written to the concepts as expressed through the OSS stack (not copied from dumps), each with the correct answer, an explanation, and a link to an authoritative doc.

#### Scenario: Quiz format
- **WHEN** a reader opens any checkpoint quiz
- **THEN** questions are scenario-based, answers are separated from questions (collapsible), and every answer includes an explanation with a doc link

#### Scenario: Checkpoint gates the phase
- **WHEN** a domain phase ends
- **THEN** the plan directs taking that domain's checkpoint, and scores below the pass bar route the flex day to remediation

### Requirement: Readiness gate
The assessment section SHALL define a self-readiness rule under `assessment/readiness.md` — a target checkpoint score across all four banks plus completion of the full-stack capstone — with a remediation loop where every missed question maps back to a tracker row.

#### Scenario: Gate enforcement
- **WHEN** a checkpoint attempt scores below the readiness target
- **THEN** the process directs logging missed objectives in the tracker and repeating remediation before declaring readiness
