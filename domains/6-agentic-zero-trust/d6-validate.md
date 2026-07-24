# Red-Team the Agent — attack the action/identity surface *(beyond-blueprint)*

Domain 6 built a tool-using agent under zero trust: scoped delegated identity ([`d6-identity`](d6-identity.md)), per-call tool authorization ([`d6-tools-mcp`](d6-tools-mcp.md)), consequential-action gating ([`d6-action-gating`](d6-action-gating.md)), and identity-based multi-agent trust ([`d6-multi-agent`](d6-multi-agent.md)). This track attacks *those exact controls* and maps every finding to its **OWASP Agentic** / **MITRE ATLAS** technique — so a bypass isn't "the agent did a bad thing," it's `AI Agent Tool Invocation` ↔ `AML.T0053` with the missing control named.

**Boundary vs. [`d5-ai-redteam`](../5-offensive-validation/ai-redteam.md):** Domain 5 attacks the **chat/RAG guardrail** (does the model *say* something unsafe — jailbreak, content, system-prompt leak). This track attacks the **agent's tools, identity, and actions** (does the agent *do* something unsafe — fire a consequential tool, use a token beyond scope, launder privilege). Same purple-team method, different surface; run both.

## Tools
| Tool | What it does here | Runs |
|---|---|---|
| **[garak](https://github.com/NVIDIA/garak)** (reference) | LLM/agent vulnerability scanner — injection & leakage probes, pointed at the agent's input surface | `pipx run garak -G lab-infra/offense/localhost-ollama.json` against the local agent |
| **[PyRIT](https://github.com/Azure/PyRIT)** (reference) | Microsoft's risk-identification toolkit — multi-turn orchestration to steer the agent toward a gated action | `python lab-infra/offense/pyrit_multiturn.py`, extend the skeleton |
| **poisoned tool result / document** | hand-crafted indirect injection carrying an *action* instruction ("also call `submit_change`…") | you author it |

## The attack ↔ control map (what you're actually testing)
| Attack | Agentic risk / ATLAS | The D6 control that should stop it |
|---|---|---|
| **Injection → action** (poisoned content tells the agent to fire a consequential tool) | indirect injection `AML.T0051.001` → `AML.T0053` AI Agent Tool Invocation | `action-gate` (`interrupt()` halts it) + `mcp-authz` |
| **Delegated-token authz bypass** (use an agent token outside its scope/audience) | Excessive Agency / privilege abuse | `agent-deleg` scoped, audience-bound, short-lived token — refused at the resource |
| **Confused-deputy via tools** (steer the agent's standing privilege to attacker ends) | `AML.T0053` + token passthrough | `mcp-authz` keyed on the *delegated* subject; no token passthrough |
| **Memory poisoning** (persist an instruction that re-fires next session) | agentic memory/persistence abuse | scoped context + gating on the re-fired action |

## Method (the four steps, agent flavor)
The four steps are defined canonically in [`purple-team.md`](../5-offensive-validation/purple-team.md) (with the diagram and the "document the gap" loop); here in agent flavor:
1. **Build** — the agent + controls are up from `d6` (`lab-infra/agentic`).
2. **Name** — pick the attack + its OWASP-Agentic / ATLAS technique (table above).
3. **Fire** — run the probe / craft the poisoned input **against the local agent** (`http://localhost:<agent-port>` / in-cluster) — never a hosted agent or model API.
4. **Confirm** — the control blocks or gates it (the token is refused, the action pauses at `interrupt()`, the deputy stays unconfused). Where an attack **gets through**, that's the finding: record it against the technique id and name the missing control ("the injection reached `submit_change` — the gate wasn't wired on that node").

## Standards
Offense: OWASP Agentic AI — Threats & Mitigations (+ the emerging Agentic Top 10), MITRE ATLAS (`AML.T0051`/`AML.T0053`/`AML.T0057`). Governance: **NIST AI RMF** *Measure* (you are measuring agentic risk) and *Manage* (you remediate the gaps). Defensive counterpart: the D6 controls themselves.

**Resources:**
- [MITRE ATLAS — AML.T0053 AI Agent Tool Invocation (the agentic tool-abuse technique)](https://atlas.mitre.org/techniques/AML.T0053) `[depth]` (~10 min)
- [MITRE ATLAS — AML.T0051 LLM Prompt Injection (direct/indirect/triggered)](https://atlas.mitre.org/techniques/AML.T0051) `[depth]` (~10 min)
- [OWASP Agentic AI — Threats & Mitigations (the agentic threat taxonomy)](https://genai.owasp.org/resource/agentic-ai-threats-and-mitigations/) `[depth]` (~30 min)
- [garak — LLM/agent vulnerability scanner: injection & leakage probes](https://github.com/NVIDIA/garak) (reference) — start from the shipped [`lab-infra/offense/localhost-ollama.json`](../../lab-infra/offense/localhost-ollama.json) instead of authoring the REST generator config from scratch
- [Microsoft PyRIT — multi-turn attack orchestration](https://github.com/Azure/PyRIT) (reference) — start from the shipped [`lab-infra/offense/pyrit_multiturn.py`](../../lab-infra/offense/pyrit_multiturn.py) instead of an empty file
- [NIST AI Risk Management Framework — Measure & Manage functions](https://www.nist.gov/itl/ai-risk-management-framework) (reference)

## Self-check
1. Map an "injection → `submit_change`" success to its ATLAS technique(s), and name which D6 control (there are two candidates) should have stopped it and why it didn't.
2. Why test both the *token* surface (authz-bypass) **and** the *action* surface (gating) — what class of failure does each find that the other misses?
3. What is the value of recording a real gap ("the gate wasn't on that node") over reporting a clean pass — and how does that honesty rule mirror Domain 5?
