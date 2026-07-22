## Context

OSS-500 is organized as Domains 0–5 (SC-500-anchored), each subsection = a note + a prove-it lab that stands up real OSS, observes the control hold, then destroys it. Two beyond-blueprint precedents already exist: the `d1-ztna` five-models subsection and all of Domain 5 (offensive validation). The `standards-map.md` spine pairs each control with the attack that validates it. Domain 3 secures the LLM *application* (chat/RAG) but the **agentic** surface — an agent that holds identity and calls tools/takes actions — is unbuilt. This domain adds it, exam-agnostic, reusing infra already in the course: Keycloak (`d1-idp`), SPIFFE/SPIRE (`d1-workload-identity`), OPA (`d1-governance`/`d3-ai`), Vault (`d2-secrets`), Ollama gateway (`d3-ai`), and garak/PyRIT (`d5-ai-redteam`).

## Goals / Non-Goals

**Goals:**
- Teach agentic security as **build → prove**, hands-on, on a single laptop: each subsection stands up a control and demonstrates an observable (a refused token, a denied tool call, a paused action, a rejected peer, a blocked attack).
- Make the agent a first-class **principal**: separate its *workload* identity (SPIFFE SVID) from its *delegated* authority to act for a user (OAuth token exchange) — the direct continuation of the course's identity/zero-trust through-line.
- Keep every subsection **standards-paired** (offense↔defense) and wired into `standards-map`.
- Reuse existing lab-infra so the domain reads as the capstone that ties identity, policy, secrets, and detection together — not a bolt-on.

**Non-Goals:**
- No cloud-hosted or managed agents; local **kind + Compose only**.
- One agent framework (**LangGraph**); not a framework survey. A brief "the same hook exists elsewhere" aside is allowed, not a parallel implementation.
- Not re-teaching chat/RAG guardrails (that's `d3-ai`/`d5-ai-redteam`); `d6-validate` targets the **action/identity** surface only.
- Multi-region SPIRE federation stays a **walkthrough** (impractical to run fully on one host).
- No changes to Domains 1–5 objective ids, labs, or exam mappings.

## Decisions

**D1 — LangGraph as the agent framework.** Chosen over a minimal custom loop and over AutoGen/Google ADK because its explicit graph/state model puts the security seams where a learner can see them, and its **native `interrupt()`** primitive is a first-class home for the D3/`d6-action-gating` human-approval gate. `langchain-mcp-adapters` gives MCP tool binding; it runs against the local Ollama models from `d3-ai`; supervisor/swarm patterns cover `d6-multi-agent`. *Alternative considered:* a ~100-line custom agent (maximally legible) — rejected as less representative of what people ship; the framework's realism is the point of the "real framework" choice.

**D2 — Two distinct identities per agent.** The agent's **workload identity** is a SPIRE-issued **SVID** (who the process is); its authority to act for a user is a **scoped, short-lived OAuth token minted via Keycloak Token Exchange (RFC 8693)** (what it may do on whose behalf). Teaching these as separate axes is the core insight of `d6-identity` and the answer to "an agent is a new kind of principal." *Alternative:* collapse into one long-lived agent credential — rejected; it is exactly the anti-pattern (the agent equivalent of a static service-principal secret) the domain exists to refute.

**D3 — OPA is the single policy engine across tools, actions, and routes.** Every tool/MCP call (`d6-tools-mcp`) and every action-consequentiality decision (`d6-action-gating`) is an OPA (Rego) allow/deny, reusing the `d3-ai` gateway pattern. One engine keeps the mental model consistent and the labs composable; policy is the PDP, the agent/gateway is the PEP — NIST 800-207 applied to agent actions and tool use.

**D4 — Zero-trust framing end to end.** The organizing principle is 800-207: never trust the agent's context; authenticate identity at every hop (resource access, tool call, agent-to-agent), authorize least privilege, and gate consequential actions. Multi-agent trust (`d6-multi-agent`) uses **SPIFFE mTLS** so peer trust is identity-based, not network-based — the same lesson as the D2 mesh, now between agents.

**D5 — `d6-validate` is offense against the agent's action/identity surface.** garak/PyRIT (reused from D5) are aimed at: injection→action (an ingested/tool-returned instruction that tries to fire a consequential action), delegated-token authz bypass (using an agent token beyond its scope), confused-deputy via tools, and memory poisoning. Each finding maps to its OWASP-Agentic / MITRE ATLAS technique and the control that should stop it — the same purple-team method as Domain 5, explicitly complementary to `d5-ai-redteam` (which attacks the chat/RAG guardrail).

**D6 — Capability shape.** The five subsections are facets of one capability, `agentic-zero-trust`, expressed as one requirement per subsection (build+prove) plus a requirement for the standards-map/tracker wiring. Objective ids follow the course convention (`d6-<subsection>` subsections; per-objective ids like `agent-deleg`, `mcp-authz`, `action-gate`, `multi-agent`, `agent-redteam`). Link citations follow the `resource-citation` standard so `lint:links`/`lint:content` stay green.

## Risks / Trade-offs

- **Bleeding-edge, fast-moving specs (MCP auth, OWASP Agentic Top 10 still stabilizing).** → Pin to the most stable published anchors, name the section in link text so a moved anchor still guides the reader, and mark genuinely canonical homes `(reference)`. Treat the domain as living content.
- **Laptop resource ceiling** (LangGraph + MCP + SPIRE + Keycloak + OPA + Ollama at once). → Reuse already-running components rather than new stacks; scope each lab to bring up only what it needs; mark the heaviest multi-agent + federation paths as walkthrough where a full run isn't laptop-feasible.
- **`d6-validate` overlapping `d5-ai-redteam`.** → Hard scope boundary: D5 attacks the chat/RAG guardrail; D6 attacks tools/identity/actions. Each note cross-links the other and states the boundary.
- **Framework churn (LangGraph API changes).** → Teach the *pattern* (where the token-exchange call, the OPA check, the `interrupt()` gate go) with the framework as the vehicle; keep code minimal and the security hook, not the framework glue, in focus.
- **Keycloak token-exchange is a preview/opt-in feature.** → Document enabling it explicitly in `lab-infra/agentic`; if a version makes it impractical, the delegated-token issuance step degrades to a documented walkthrough while the *validation* (over-broad token refused) stays hands-on.

## Migration Plan

Additive only. Order: (1) author the 5 notes + labs + `lab-infra/agentic/`; (2) wire `standards-map.md`, `tracker.yaml`, `labs/README.md`; (3) `npm run gen:md`; (4) `npm run lint:links` green; (5) bump the study-hub `content/oss-500` submodule, `lint:content` + tests green, confirm the new notes/labs render. Rollback is deletion of the new domain dir + reverting the three wiring edits — Domains 1–5 are untouched.

## Open Questions

- Exact per-objective id granularity in `tracker.yaml` (one objective per subsection vs. a few) — resolved during authoring to match sibling domains' density.
- Whether `d6-multi-agent` ships one lab (A→B trust) or two (add a supervisor-orchestration variant) — default one hands-on lab; a second is a follow-up if it earns its keep.
