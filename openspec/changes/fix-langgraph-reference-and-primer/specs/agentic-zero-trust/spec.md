## ADDED Requirements

### Requirement: The action-gating objective teaches the LangGraph execution model it asks the learner to implement

The `d6-action-gating` note SHALL teach the LangGraph execution model that implementing human-in-the-loop pause/resume requires — nodes, graph state, the checkpointer that persists state between steps, and `interrupt()` (how it suspends a run so an approver can act before the graph resumes) — so a learner can author the gate, not merely read the shipped `agent.py`. The note's LangGraph reference SHALL deep-link to the human-in-the-loop / `interrupt()` documentation (not the repository root) and SHALL be marked load-bearing per the necessity-tag standard.

#### Scenario: The learner can implement pause/resume from the note

- **WHEN** a learner reaches the `d6-action-gating` implementation step
- **THEN** the note has defined node/state/checkpointer and `interrupt()` semantics, so the learner can author the pause/resume gate from course material rather than reverse-engineering it from `agent.py`

#### Scenario: The LangGraph reference points at the interrupt() doc

- **WHEN** a learner opens the note's LangGraph reference
- **THEN** it lands on the human-in-the-loop / `interrupt()` documentation (not the repo root) and is tagged as required reading for the objective
