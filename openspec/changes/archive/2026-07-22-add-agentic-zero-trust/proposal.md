## Why

OSS-500 secures the LLM *application* surface well (Domain 3: prompt injection, guardrails, secure RAG, LLM red-teaming), but treats **agentic** security — autonomous, tool-using, multi-step agents — only as a principle ("least agency"), never as a hands-on topic. The field's center of gravity in 2026 is agents + MCP + delegated identity, and an agent is a genuinely new kind of **principal**: it needs its own workload identity *and* a scoped, delegated authority to act for a user. Nothing in the course builds, secures, or red-teams an actual agent. This is the gap this change closes — as portfolio-grade, exam-agnostic enrichment on top of the existing spine.

## What Changes

- **New Domain 6 — "Agentic Zero Trust"** `(beyond-blueprint)`: a self-contained track that both **builds** agentic security controls and **red-teams** them (unlike Domain 5, which only validates). Delivered as five subsections, each a note plus at least one runnable "prove-it" lab, all built on **LangGraph + `langchain-mcp-adapters` + local Ollama**, reusing existing course infra (Keycloak, SPIFFE/SPIRE, OPA, Vault, garak/PyRIT).
  - `d6-identity` — agent delegated identity: Keycloak **token-exchange (RFC 8693)** scoped on-behalf-of tokens + a **SPIRE SVID** for the agent workload; workload identity vs. delegated authority made distinct.
  - `d6-tools-mcp` — tool / **MCP** trust boundaries: OPA authorizes every tool call; MCP server authn via Keycloak.
  - `d6-action-gating` — autonomous-action zero trust: LangGraph **`interrupt()`** + OPA action-class policy → human/deterministic approval; NIST 800-207 PEP/PDP applied to *actions*.
  - `d6-multi-agent` — multi-agent trust: SPIFFE mTLS peer auth; cascading/wormable injection A→B.
  - `d6-validate` — red-team the agent's **action/identity** surface (injection→action, delegated-token authz bypass, confused-deputy, memory poisoning); complementary to `d5-ai-redteam` (chat/RAG guardrail).
- **New lab-infra component** `lab-infra/agentic/` (LangGraph agent(s) + MCP server(s), wired to Keycloak/OPA/SPIRE/Ollama; `up.sh`/`down.sh` + README; deploy→verify→destroy). Offense reuses `lab-infra/offense/`.
- **`standards-map.md` gains an agentic offense↔defense pairing**: NIST 800-207/207A, RFC 8693, SPIFFE, the MCP authorization spec, OWASP Agentic AI (Threats & Mitigations / emerging Agentic Top 10), MAESTRO, and MITRE ATLAS agentic techniques.
- **Tracker + catalog updated**: `assessment/data/tracker.yaml` gains the `d6` domain, subsections, and objectives (marked beyond-blueprint); `labs/README.md` gains a Domain 6 section; `npm run gen:md` regenerates the tracker view.

## Capabilities

### New Capabilities
- `agentic-zero-trust`: The curriculum's coverage of securing autonomous, tool-using AI agents under zero-trust principles — delegated agent identity, tool/MCP trust boundaries, autonomous-action gating, multi-agent trust, and offensive validation of the agent's action/identity surface — each taught as a standards-paired, hands-on prove-it lab.

### Modified Capabilities
<!-- The build-oss-500-course domain capabilities are not archived to openspec/specs/,
     so this change adds a new capability rather than deltaing them. Domains 1–5 and
     their exam mappings are untouched; standards-map/tracker/labs README edits are
     additive wiring for the new domain. -->
- None (Domains 1–5 unchanged; this is purely additive).

## Impact

- **Content (new)**: `domains/6-agentic-zero-trust/` (5 notes) and `labs/d6-*.md` (≥5 labs) created; `domains/standards-map.md`, `assessment/data/tracker.yaml`, `labs/README.md` edited to wire the domain in. New external links follow the `resource-citation` standard so `lint:links`/`lint:content` stay green.
- **Lab-infra (new)**: `lab-infra/agentic/` (LangGraph + MCP + wiring); depends on already-present Keycloak/OPA/SPIRE/Ollama components; local kind + Compose only.
- **Tooling**: `npm run gen:md` regenerates `assessment/tracker.md`; no lint/script changes required (the new domain is covered by existing `domains/**`/`labs/**` link linting).
- **study-hub**: content-only from its side — after the domain lands, bump the `content/oss-500` submodule and confirm `lint:content` + tests stay green and the new notes/labs render.
- **No change to Domains 1–5**: objective ids, existing labs, and exam mappings are untouched; `d6-validate` is scoped to the agentic action/identity surface so it does not duplicate `d5-ai-redteam`.
