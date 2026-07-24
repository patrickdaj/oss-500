# Add a LangGraph execution-model primer and fix the wrong reference link

## Why

D6 `d6-action-gating` asks the learner to **implement** human-in-the-loop pause/resume — which in LangGraph means understanding its execution model (nodes, graph state, the checkpointer that persists state between steps, and `interrupt()`), yet no note teaches that model, and the persona can *read* the shipped `agent.py` but cannot author the framework from the note (audit P7, line 37). Compounding it, the cited LangGraph link points at the **repo root**, not the human-in-the-loop / `interrupt()` documentation — so the one reference that would close the gap sends the learner to a landing page. Two cheap, additive fixes.

## What Changes

- Add a **LangGraph execution-model primer** to `d6-action-gating`: node/state/checkpointer and how `interrupt()` suspends a run so an approver can act before resume — enough to implement the pause/resume gate, not just read it.
- **Fix the reference**: replace the repo-root LangGraph link with a deep link to the human-in-the-loop / `interrupt()` documentation, and mark it load-bearing (per `rank-learning-references`) since the objective under-teaches the framework mechanics.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agentic-zero-trust` — adds a requirement that the `d6-action-gating` objective teach the LangGraph execution model it asks the learner to implement, and that its LangGraph reference deep-link to the human-in-the-loop/`interrupt()` doc rather than the repo root.

## Impact

- Affected specs: `agentic-zero-trust` (one ADDED requirement).
- Affected content (at implementation time): the `d6-action-gating` note under `domains/6-agentic-zero-trust/` gains the primer; its LangGraph link is retargeted and tagged load-bearing.
- Turns "can read `agent.py`" into "can implement the action gate."
