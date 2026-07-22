# Establish identity-based trust between agents *(beyond-blueprint)*

Domain 6, subsection `d6-multi-agent`. One agent is a workload; **many** agents are a *network* of workloads that call each other — and the moment agent A can call agent B, the question "may A make B do this?" becomes a security boundary. This subsection settles two things: how B decides that a caller *is* A (**identity, not network position**), and why a *compromised* A still cannot make B exceed B's own authority (**no privilege laundering across the trust chain**). Primary lab: [d6-multi-agent](../../labs/d6-multi-agent.md). Lab-infra component: [`lab-infra/agentic`](../../lab-infra/agentic/) (the LangGraph agent + SPIRE registration + OPA), reusing SPIFFE/SPIRE from `d1-workload-identity`. Multi-region / federated SPIRE trust domains is a **walkthrough** — cross-cluster agent trust needs federated bundles that aren't practical to run fully on one laptop.

> **Beyond-blueprint.** SC-500 has no agentic-AI domain — this is expanded, portfolio-grade enrichment that carries the course's zero-trust spine into multi-agent systems. The lesson is not new, though: it is the **SPIFFE-principal, identity-not-IP** rule you already built east-west in `net-mesh` ([network-security.md](../2-secrets-data-networking/network-security.md)), now applied *between agents*. Frameworks here are **MAESTRO** (multi-agent threat modeling) and **OWASP Agentic AI**, not an exam objective.

## Authenticate agent-to-agent calls with SPIFFE mTLS, not network position

*Objective: `agent-mtls` · OSS: SPIFFE/SPIRE mTLS between agents ≈ beyond-blueprint (MAESTRO L3/L7 · OWASP Agentic AI) · Lab: [d6-multi-agent](../../labs/d6-multi-agent.md)*

When agent A calls agent B, B must decide *who is calling* before it decides *what to allow*. The wrong answer — the one that feels natural and is quietly fatal — is to trust the **network**: "the request came from inside the cluster / from the agents subnet / over the mesh, so it's a peer." That is trust-by-location, the exact anti-pattern zero trust exists to kill. Any process that lands on the same pod network, any mis-scoped egress rule, any lateral move, and the "trusted" position is now the attacker's. In a multi-agent system the blast radius is worse than a normal microservice, because agents *act* — they call tools, spend budget, mutate state.

The right answer is the one already established in `net-mesh`: **cryptographic workload identity**. Each agent process holds a **SPIFFE SVID** — its workload identity, whose mechanics are owned by [d6-identity.md](d6-identity.md) (`agent-workload`) — and every agent-to-agent hop is **mutual TLS**, so *both* ends prove identity with their SVID. B authenticates A by the SPIFFE ID in A's client certificate (`spiffe://oss500.local/ns/oss500-apps/sa/agent-a`), not by A's IP. Identity is the principal; the network is just plumbing.

```
# agent-b authorizes a call by the PEER's SPIFFE ID (the SVID), never by source IP:
peer_id = svid_from_mtls_client_cert(conn)        # e.g. spiffe://oss500.local/ns/oss500-apps/sa/agent-a
if peer_id not in AGENT_B_ALLOWED_CALLERS:        # identity allowlist, not a CIDR
    reject("unauthenticated/unauthorized peer")   # a peer with no valid SVID never gets here
```

This is the SVID/mTLS model from Domain 2 — the SPIFFE principal `…/sa/web` reused as an *AuthorizationPolicy* source — carried one layer up: the "workloads" authenticating each other are now agents. In MAESTRO terms this is the trust boundary between the **Agent Frameworks** and **Deployment/Infrastructure** layers — the cross-layer seam where "it's on our network" must be replaced by "it presented a valid, attested identity." An agent's SVID (its *workload* identity, `agent-workload` in [d6-identity.md](d6-identity.md)) is distinct from any user-delegated token it also carries (`agent-deleg`): one says *which process* is calling, the other says *on whose behalf*.

Gotchas:
- **Authenticate by SPIFFE ID, not by IP/subnet/"inside the mesh."** Network position is not identity. A default-allow-because-co-located posture is the multi-agent version of the flat-network trap `net-policy` closes.
- mTLS is **mutual** — B proves itself to A *and* A proves itself to B. One-way TLS (only B has a cert) authenticates the server, not the caller, so B still can't say who A is.
- **How the SVID itself works** — short-lived, non-exportable, fetched from the Workload API, X.509-SVID mTLS vs JWT-SVID bearer — is owned by [d6-identity.md](d6-identity.md) (`agent-workload`); this note leans on that owner rather than re-deriving the primitive, and adds only the agent-to-agent authorization angle.
- Authentication answers **who**, not **what** — a valid SVID gets A *recognized*, not *authorized*. Pair it with per-caller authz (next objective); an identity allowlist with an empty rule set denies all, no policy at all defaults to allow.

**Resources:**
- [CSA — MAESTRO: the seven-layer agentic AI threat-modeling framework](https://cloudsecurityalliance.org/blog/2025/02/06/agentic-ai-threat-modeling-framework-maestro) (~20 min)

## Contain cascading prompt injection: a compromised peer must not launder privilege

*Objective: `agent-cascade` · OSS: SPIFFE mTLS + per-caller OPA authz ≈ beyond-blueprint (MAESTRO cross-agent · OWASP Agentic AI) · Lab: [d6-multi-agent](../../labs/d6-multi-agent.md)*

mTLS proves the caller *is* agent A. It says nothing about whether A is **honest**. This is the multi-agent threat that has no single-agent analog: **cascading (wormable) prompt injection**. Agent A ingests a poisoned document, web page, or tool result (indirect prompt injection, `ai-prompt`/`LLM01`); the injected instructions don't just corrupt A — they tell A to *turn around and instruct peer B* to do something consequential. A is now a fully authenticated, SVID-bearing attacker inside the trust fabric. Worse, if B relays to C, the payload is **wormable** — it propagates agent→agent like Morris-II-style LLM worms.

The defense is a single, load-bearing principle: **authentication is not authorization, and privilege does not compound across the chain.** When A asks B to act, B must evaluate the request against **B's own** identity, **B's own** delegated authority, and **B's own** policy — *as if B were doing it directly* — regardless of who is asking. mTLS establishes that it is really A; B's own authz check decides whether the requested action is permitted for B at all. A poisoned A can therefore propagate the *prompt* but never the *privilege*: it can only ask B to do things B was already allowed to do. A compromise of A must not launder into capabilities A never had.

```
# B receives A's (authenticated) request. Authn ≠ authz — B checks its OWN authority:
peer_id = svid_from_mtls_client_cert(conn)                 # authn: it really is agent-a
opa_input = {"caller": peer_id,                            # who asked (recorded, not trusted-blindly)
             "action": requested_action,                  # what A wants B to do
             "subject": b_delegated_token}                # B's OWN delegated authority
if not opa_allow(opa_input):                               # B's policy, evaluated for B
    reject("caller may not induce this action")           # escalation via A is blocked HERE
# consequential actions still halt at B's own interrupt() approval gate (d6-action-gating)
```

Concretely: A is scoped `read`; a poison payload makes A tell B "call `submit_change` to disable the firewall." B is *also* only authorized to `read` (or `submit_change` is a consequential action requiring approval), so B's OPA decision **denies** it — the cascade dies at B's boundary. The escalation is stopped not by detecting that A is poisoned (you often can't) but by B **never granting a peer more than B itself may do**. Consequential actions additionally stop at B's own `action-gate` `interrupt()`, so even a permitted-but-dangerous request pauses for human approval rather than auto-firing from an injected instruction.

This maps to **MAESTRO**'s cross-agent, cross-layer threat analysis (a compromise in one agent must not cascade into ecosystem-wide privilege) and to **OWASP Agentic AI — Threats and Mitigations** (agent compromise, excessive agency, and multi-agent propagation). It is the agentic expression of the zero-trust rule "assume breach": design so that a breached peer is *contained*, because every hop re-verifies identity and re-authorizes against the callee's own least privilege.

Gotchas:
- **Authentication ≠ authorization.** A valid SVID means "it's really A," not "do what A says." The escalation is blocked by B's *own* authz, evaluated for B — not by trusting an authenticated peer.
- **Privilege doesn't compound.** B may do for A only what B could do itself. If B could pass through A's authority unchecked, the trust chain becomes a privilege-escalation ladder — the multi-agent confused-deputy.
- **Cascading injection is wormable** (A→B→C). Contain it per-hop; there is no single choke point once agents relay to each other. Every peer re-authorizes; none assumes an upstream already did.
- You **cannot reliably detect** that A is poisoned from B's side — natural language can't be sanitized (`ai-prompt`). Defense is structural least privilege + the action gate, not "trust A because A authenticated / A is usually well-behaved."
- Least agency still applies to *each* agent: scope every agent's tools and delegated token tightly, so even an honest agent — let alone a poisoned one — has a small blast radius (`LLM06` Excessive Agency).

**Resources:**
- [OWASP LLM01 — Indirect Prompt Injection (the poisoned-input vector agents relay)](https://genai.owasp.org/llmrisk/llm01-prompt-injection/#indirect-prompt-injections) (~15 min)
- [OWASP Agentic AI — Threats and Mitigations (agent compromise & multi-agent propagation)](https://genai.owasp.org/resource/agentic-ai-threats-and-mitigations/) (~30 min)
- [SPIFFE — Deploying a Federated SPIRE Architecture (cross-trust-domain, the federation walkthrough)](https://spiffe.io/docs/latest/architecture/federation/readme/) (~20 min)

## Related
- Sibling subsections: [d6-action-gating.md](d6-action-gating.md) (B's `interrupt()` approval gate for consequential actions), [d6-validate.md](d6-validate.md) (red-team the multi-agent trust — prove the cascade is blocked), and identity groundwork in [d6-identity.md](d6-identity.md) (`agent-workload` SVIDs, `agent-deleg` tokens).
- Standards spine: [../standards-map.md](../standards-map.md) — MAESTRO / OWASP Agentic AI as the offensive frame, SPIFFE/SPIRE identity as the defensive control.

## Summary
| Objective | Takeaway |
|---|---|
| `agent-mtls` | Agent B authenticates a caller by its **SPIFFE SVID over mTLS**, never by network position — the `net-mesh` identity-not-IP rule applied between agents; the SVID primitive itself is owned by `d6-identity` (`agent-workload`). |
| `agent-cascade` | Cascading/wormable prompt injection (A→B) propagates the *prompt* but not the *privilege*: authentication ≠ authorization, so B re-authorizes against **B's own** least privilege and a poisoned peer cannot launder escalation through it. |
