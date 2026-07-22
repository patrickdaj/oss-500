# Gate the autonomous action — approval before consequence *(beyond-blueprint)*

> **Beyond-blueprint.** SC-500 is a cloud-and-AI *defensive* exam; it does not cover autonomous agents or action safety. Domain 6 is expanded, portfolio-grade enrichment — it builds and red-teams a tool-using agent under zero-trust principles, extending the controls from Domains 1–4 onto the agent. Domains 1–4 keep their exam mapping intact; treat this as the frontier that follows from them.

Domain 6, subsection `d6-action-gating` (autonomous-action gating). [`d6-tools-mcp`](d6-tools-mcp.md) decided *may this tool call happen* — authorization. This subsection decides the next question: *even if it's authorized, should a **consequential** action fire autonomously, or pause for a human?* An agent that can write, pay, email, or run code is one prompt-injection away from doing so with attacker intent, and `mcp-authz` alone won't save you when the action is *within* the agent's rights but *wrong*. The zero-trust move (NIST SP 800-207) is to treat every consequential action as a request to a **policy enforcement point**: a **PDP** (OPA) classifies whether the action is consequential, and consequential actions **halt at an approval gate** — implemented with LangGraph's native **`interrupt()`** — before they execute. This is **OWASP LLM06 Excessive Agency** turned from a warning into a built control.

Primary lab: [d6-action-gating](../../labs/d6-action-gating.md). Lab-infra component: [`lab-infra/agentic`](../../lab-infra/agentic/) — the OPA `action-class` policy (`opa/action-class.rego`) and the agent's `gate()` wrapper (`agent/agent.py`) that calls `interrupt()` before a consequential tool node runs. It **reuses** OPA (`d3-ai`/`d1-governance`) and the scoped identity from [`d6-identity`](d6-identity.md), and composes with the tool authorization in [`d6-tools-mcp`](d6-tools-mcp.md). Standards: NIST SP 800-207 (PEP/PDP, applied to *actions*), OWASP Agentic AI — Threats & Mitigations, OWASP LLM06; see [`../standards-map.md`](../standards-map.md).

## Classify the action, then pause consequence for approval

*Objective: `action-gate` · OSS: OPA action-class + LangGraph `interrupt()` ≈ beyond-blueprint (NIST 800-207 PEP/PDP applied to agent actions) · Lab: [d6-action-gating](../../labs/d6-action-gating.md)*

Authorization and consequence are **different questions**. `mcp-authz` asks "may this identity call `submit_change` with these arguments?" — a yes/no on *permission*. Action-gating asks "this call is permitted, but it changes state / spends money / runs code — should it fire without a human saying go?" The failure mode it defends is the one that makes agents dangerous: a **permitted** action, invoked because an injected instruction steered the agent there. The agent had the right; the intent was hijacked. You cannot fix that with more authorization — the caller *is* authorized. You fix it by making consequence **deliberate**.

Two pieces make the gate. First, a PDP that **classifies** an action as consequential vs. safe — a deterministic policy, not the model's own judgement (a compromised model will happily rate its malicious action "safe"). Consequential = it writes, executes, spends, or egresses; everything else (pure reads) proceeds. The reference policy keys on the action's effect, not the model's say-so:

```rego
package agentic.actions

# action-gate: consequential actions must pause for human/deterministic approval.
consequential if { input.action.tool == "submit_change" }
consequential if { input.action.effect == "write" }
consequential if { input.action.effect == "exec" }
consequential if { input.action.effect == "network_egress" }

requires_approval := consequential      # pure reads/lookups run without a gate
```

Second, an **enforcement point** in the agent's control flow that halts on `requires_approval` and waits for an out-of-band decision. LangGraph's **`interrupt()`** is exactly this: called inside a node, it *pauses the graph*, surfaces a payload (what the agent wants to do and why) to a human, and resumes only when the graph is invoked again with an explicit decision. The agent's `gate()` wrapper runs the PDP and, on a consequential verdict, interrupts before the tool executes:

```python
def gate(action: dict) -> None:
    result = opa("agentic/actions", {"action": action})   # PDP: consequential?
    if result.get("requires_approval", True):             # default-deny: unknown → require approval
        decision = interrupt({"approve": result["reason"], "action": action})
        if decision != "approve":
            raise PermissionError(f"action refused at approval gate: {action}")
```

The security property this buys: **an injected instruction cannot auto-fire a consequential action.** A poisoned prompt or a hostile tool result can *route the agent toward* `submit_change`, but the graph stops at `interrupt()` — the write doesn't happen until a human approves, out of band, seeing exactly what would run. The injection reached the decision point; it could not cross it autonomously. For the sharpest-edged actions (code execution), pair the gate with a **constrained sandbox** — the approved code runs with dropped capabilities, no network, read-only mounts (the pod-hardening posture from `d3-podsecurity`), so even an approved-but-wrong exec is contained.

- **Default-deny on classification.** If OPA errors or the action is unknown, treat it as consequential and gate it — `requires_approval := true` on the unknown path. Failing open here means an unclassified action runs unattended.
- **The classifier must be deterministic, not the model.** Asking the LLM "is this dangerous?" lets a jailbroken model wave its own action through. Effect-based Rego (does it write/exec/egress?) can't be talked out of its verdict.
- **Gate on consequence, not on suspicion.** You are not trying to *detect* that the agent was compromised (you'll miss subtle cases). You gate *every* consequential action regardless — structure, not detection, is what holds when the injection is clever.

Gotchas:
- **AuthZ ≠ gating.** `d6-tools-mcp` decides *may it happen*; `d6-action-gating` decides *should a permitted consequential action pause*. `submit_change` is authorized there **and** gated here — two independent controls; a scenario may hinge on which one a given failure needed.
- **`interrupt()` is a pause, not a prompt string.** The control is that the graph *halts and cannot proceed* without an external approve/deny — not that the model was "told to ask first" (a model can ignore an instruction; it cannot ignore a suspended graph).
- **Human-in-the-loop must be genuinely out of band.** If the "approval" is another LLM call or an agent-supplied token, a prompt injection can forge it. The approver is a human or a deterministic non-LLM check.
- **Least agency still applies first.** Gating is the backstop for actions the agent legitimately needs; it is not a licence to give the agent broad tools. Scope tools tightly (`d6-tools-mcp`), *then* gate the consequential ones.

**Resources:**
- [LangGraph — Human-in-the-loop with `interrupt()` (pause a graph for approval)](https://github.com/langchain-ai/langgraph) (~20 min)
- [OWASP LLM06: Excessive Agency (autonomy / action risk)](https://genai.owasp.org/llmrisk/llm06-excessive-agency/) (~15 min)
- [OWASP Agentic AI — Threats & Mitigations (excessive agency / unsafe autonomy)](https://genai.owasp.org/resource/agentic-ai-threats-and-mitigations/) (~30 min)
- [NIST SP 800-207 Zero Trust Architecture — PEP/PDP tenets](https://csrc.nist.gov/pubs/sp/800/207/final) (reference)

## Reference solution

The lab **guides you to build** the classifier and wire the gate yourself — write the Rego, wrap the consequential node, reach the observable (a paused action). Check against the reference **after** you've tried:

- [`lab-infra/agentic/opa/action-class.rego`](../../lab-infra/agentic/opa/action-class.rego) — the `action-class` policy: effect-based consequential classification and `requires_approval`.
- [`lab-infra/agentic/agent/agent.py`](../../lab-infra/agentic/agent/agent.py) — the `gate()` function: PDP call, default-deny on unknown, and the `interrupt()` that halts before a consequential tool runs.
- [`lab-infra/agentic/README.md`](../../lab-infra/agentic/README.md) — how the gate composes with tool authz (`d6-tools-mcp`) and the scoped identity (`d6-identity`).

## Summary
| Objective | Takeaway |
|---|---|
| `action-gate` | A deterministic OPA policy classifies an action consequential (write/exec/spend/egress); consequential actions halt at LangGraph `interrupt()` for out-of-band human approval before executing — so an injected instruction can reach the decision but cannot auto-fire it. NIST 800-207 PEP/PDP applied to agent actions; the built form of OWASP LLM06 Excessive Agency. Distinct from tool authorization (`d6-tools-mcp`) and from detecting compromise — it gates by structure. |
