# Tasks — fix-langgraph-reference-and-primer

## 1. Write the LangGraph primer

- [x] 1.1 In the `d6-action-gating` note under `domains/6-agentic-zero-trust/`, add a LangGraph execution-model primer: nodes, graph state, and the checkpointer that persists state between steps.
- [x] 1.2 Explain `interrupt()` — how it suspends a run so an approver can act before the graph resumes — enough for the learner to implement the pause/resume gate, not just read `agent.py`.

## 2. Fix the reference

- [x] 2.1 Replace the repo-root LangGraph link with a deep link to the human-in-the-loop / `interrupt()` documentation.
- [x] 2.2 Tag that reference load-bearing (`required-for-lab`) per `rank-learning-references`.

## 3. Validation

- [x] 3.1 Run `openspec validate fix-langgraph-reference-and-primer --type change --strict`.
