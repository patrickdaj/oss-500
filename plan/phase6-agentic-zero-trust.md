# Phase 6 — Agentic zero trust

Domain 6 is **beyond-blueprint** — SC-500 has no agentic-AI domain, because autonomous, tool-using agents are newer than the exam. This phase carries the course's zero-trust spine onto a **new kind of principal**: the agent. An agent is two identities at once — a workload (*which process is this?*) and a delegated authority (*what may it do, for which user?*) — and the whole domain turns on keeping them separate and gating what the agent can *do*. By its checkpoint you should be able to give an agent a SPIRE SVID and a scoped on-behalf-of token, authorize and authenticate every MCP tool call, pause a consequential action at an approval gate, and show that a poisoned peer cannot launder privilege across a multi-agent chain.

Notes live in [`domains/6-agentic-zero-trust/`](../domains/6-agentic-zero-trust/); labs in [`labs/`](../labs/); the agent, MCP server, and OPA policies in [`lab-infra/agentic/`](../lab-infra/agentic/). **This phase reuses where it can and stands up what's genuinely new:** the agentic lab-infra reuses the **Keycloak realm** from Phase 1 (`lab-infra/identity`) and the **OPA engine** from Phase 3, and loads the MCP-server / agent / OPA-policy scaffolding into `oss500-apps`. **SPIRE, though, is not deployed by any component:** Phase 1 covers SPIFFE/SPIRE only as a *walkthrough* (no server runs), and Domain 6's workload-identity steps — the agent's SVID and peer mTLS — are **directions** ([`spire/registration.md`](../lab-infra/agentic/spire/registration.md)) that assume a SPIRE server you stand up yourself. On the identity plane you actually run, an agent is a new token-exchange client on the reused Keycloak realm; its workload-SVID story is followed as directions, per the same honesty rule as Domain 5.

## Day 1 — Agent delegated identity (SVID + on-behalf-of token)

- [ ] **[2h] Read the identity notes** — [d6-identity.md](../domains/6-agentic-zero-trust/d6-identity.md) (`agent-workload`, `agent-deleg`): the SPIFFE SVID as *who the process is* (the `wi-spiffe` story on an agent), distinct from a scoped, short-lived on-behalf-of token minted per action via OAuth 2.0 Token Exchange (RFC 8693) — and the long-lived-agent-credential anti-pattern that collapses the two.
- [ ] **[2.5h] Lab — two identities, one agent** — [d6-identity](../labs/d6-identity.md) with [`lab-infra/agentic`](../lab-infra/agentic/): follow the SPIRE registration *directions* to register the agent's SVID (SPIRE isn't deployed for you — see [`spire/registration.md`](../lab-infra/agentic/spire/registration.md)), then exchange a user token for a scoped `read` token on the reused Keycloak realm. **Observable: a token minted for `read` cannot call the write tool (audience/scope mismatch, refused at the resource), and an expired token is refused 401 — the authority is bounded and evaporates.**
- [ ] **[0.5h] Quiz + note** — attempt `q6-01`–`q6-05` from [quiz-6](../assessment/data/quiz-6.yaml); note the SVID-vs-OBO-token distinction and delegation-vs-impersonation (the `act` claim) in your own words.

## Day 2 — Tool / MCP trust boundaries (authorize + authenticate every call)

- [ ] **[2h] Read the MCP notes** — [d6-tools-mcp.md](../domains/6-agentic-zero-trust/d6-tools-mcp.md) (`mcp-authz`, `mcp-authn`): default-deny OPA keyed on identity × tool × arguments (argument guardrails reject wildcard/traversal even on a permitted tool), and the MCP server as an OAuth 2.1 resource server (401 before any tool runs, audience binding, no token passthrough). AuthN precedes authZ.
- [ ] **[2.5h] Lab — build the tool boundary yourself** — [d6-tools-mcp](../labs/d6-tools-mcp.md): write the Rego (default-deny, the two allow rules, the argument guardrail) and wire the call. **Observable: a `read`-scoped caller is refused `submit_change`; a permitted `lookup` with `../../etc/*` is rejected by the argument guardrail; a caller with no validated subject gets no tool at all.** Check against the reference solution *after* you've built it.
- [ ] **[0.5h] Quiz** — `q6-06`–`q6-11` (MCP authz + authn). Note misses for the synthesis day.

## Day 3 — Autonomous-action gating (pause consequence for approval)

- [ ] **[2h] Read the action-gating notes** — [d6-action-gating.md](../domains/6-agentic-zero-trust/d6-action-gating.md) (`action-gate`): authorization vs. consequentiality; a deterministic OPA classifier (effect-based, never the model's own judgement) plus LangGraph `interrupt()` that *halts the graph* — the built form of OWASP LLM06 Excessive Agency.
- [ ] **[2.5h] Lab — gate the consequential action** — [d6-action-gating](../labs/d6-action-gating.md): write the `action-class` policy and wrap the consequential tool node with `gate()`/`interrupt()`. **Observable: an injected instruction routes the agent to `submit_change`, but the graph *pauses* at the approval gate and the write does not fire until a human approves out of band — the injection reached the decision point and could not cross it.**
- [ ] **[0.5h] Quiz** — `q6-12`–`q6-14` (action gating). 

## Day 4 — Multi-agent trust (SPIFFE mTLS, no privilege laundering)

- [ ] **[2h] Read the multi-agent notes** — [d6-multi-agent.md](../domains/6-agentic-zero-trust/d6-multi-agent.md) (`agent-mtls`, `agent-cascade`): authenticate agent-to-agent calls by SPIFFE ID over mutual TLS (never network position), and contain cascading/wormable prompt injection — B re-authorizes against **B's own** least privilege, so a poisoned peer propagates the prompt but not the privilege.
- [ ] **[2.5h] Lab — prove the cascade dies at B** — [d6-multi-agent](../labs/d6-multi-agent.md): establish SPIFFE mTLS between agents, then have a poisoned agent A instruct peer B to fire a consequential action. **Observable: B authenticates A by its SVID but re-authorizes the request against B's own policy and *denies* it (and consequential actions still halt at B's own `interrupt()`) — escalation via a compromised peer is blocked at B's boundary.**
- [ ] **[0.5h] Quiz** — `q6-15`–`q6-17` (multi-agent). Note misses.

## Day 5 — Red-team the agent (attack the action/identity surface)

- [ ] **[2h] Read the validation notes** — [d6-validate.md](../domains/6-agentic-zero-trust/d6-validate.md) (`av-agent-actions`): the attack ↔ control map (injection→action, delegated-token authz bypass, confused-deputy via tools, memory poisoning) mapped to OWASP Agentic / MITRE ATLAS (`AML.T0051`/`AML.T0053`). Boundary vs. `d5-ai-redteam`: this attacks what the agent *does*, not what the model *says*.
- [ ] **[2.5h] Lab — attack the D6 controls you built** — [d6-validate](../labs/d6-validate.md): craft a poisoned tool result carrying an *action* instruction, and try to use an agent token beyond its scope. **Observable: the token is refused at the resource, the action pauses at `interrupt()`, and the deputy stays unconfused — or, where an attack gets through, you record it against its ATLAS technique and name the missing control ("the gate wasn't wired on that node").**
- [ ] **[0.5h] Quiz** — `q6-18`–`q6-19` (red-team the agent). 

## Day 6 — Synthesis and Checkpoint 6

- [ ] **[1.5h] Catch-up / slippage** — finish any unrun lab section (walkthrough the federated-SPIRE or HTTP-OAuth-transport pieces at depth if a host constraint blocked them). Slippage from Days 1–5 lands here.
- [ ] **[1h] Confirm every lab's proof-of-work observable** — for each d6 lab, restate the control and the refusal/pause you observed. Filter the tracker for `d6` confidence < 2.
- [ ] **[1h] Full teardown check** — bring the agentic stack down; confirm the reused Keycloak/OPA plane is in the state you want for Review.
- [ ] **Rest** — take your day off before Review.

## Checkpoint

Take **[checkpoint-6](../assessment/checkpoint-6.md)** (bank: [quiz-6](../assessment/data/quiz-6.yaml), pass ≥ 80%) in test mode on this synthesis day. Every d6 subsection is represented — agent delegated identity, tool/MCP trust boundaries, autonomous-action gating, multi-agent trust, and red-teaming the agent.

- Score **< 80%** → this day's remaining time goes to remediation: each missed question maps to `objectiveIds`; re-read that note section and re-run its lab step (prove the control again) before moving on.
- Score **≥ 80%** with every d6 objective at confidence ≥ 2 → Domain 6 is green. Proceed to the [Review & capstone](review.md) phase.

> **Beyond-blueprint note.** Domain 6 carries no SC-500 weight — it is the frontier that follows from Domains 1–4 — but [gates on its checkpoint exactly as the SC-500 phases do](overview.md#phase-map). Proof-of-work (the control refuses or pauses the attack) is the per-lab observable.
