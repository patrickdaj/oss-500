## 1. Lab-infra foundation

- [x] 1.1 Create `lab-infra/agentic/` with `up.sh`/`down.sh` + README following the deploy→verify→destroy convention; stand up a LangGraph agent runtime + `langchain-mcp-adapters` against the local Ollama models from `d3-ai`, wired to the existing Keycloak, OPA, SPIRE, and Vault components (reuse, don't re-deploy).
- [x] 1.2 Add a minimal **MCP server** exposing a few example tools (a safe read tool + a "consequential" write/exec tool) that the agent calls, so subsections 2–4 have a concrete tool surface.
- [x] 1.3 Enable/document **Keycloak Token Exchange (RFC 8693)** in the agentic component (preview feature) and a **SPIRE** registration for the agent workload SVID; note the fallback if token-exchange is impractical on a given version (issuance → walkthrough, validation stays hands-on).

## 2. `d6-identity` — Agent delegated identity

- [x] 2.1 Write `domains/6-agentic-zero-trust/d6-identity.md`: agent as a new principal — SPIFFE **workload** identity vs. RFC 8693 **delegated** on-behalf-of authority; scoped, short-lived, least-privilege tokens vs. the long-lived-agent-credential anti-pattern. Pin NIST 800-207 / RFC 8693 / SPIFFE, links per the `resource-citation` standard.
- [x] 2.2 Write `labs/d6-identity.md` (hands-on; SPIRE federation = walkthrough): mint a scoped delegated token via Keycloak token-exchange, attach the agent's SPIRE SVID, and **prove an over-broad/expired token is refused** at a resource while a correctly-scoped token succeeds.

## 3. `d6-tools-mcp` — Tool / MCP trust boundaries

- [x] 3.1 Write `domains/6-agentic-zero-trust/d6-tools-mcp.md`: MCP trust boundaries, per-call OPA authorization (identity × tool × args), MCP server authn via Keycloak / the MCP authorization spec. Standards: MCP auth spec, OWASP Agentic.
- [x] 3.2 Write `labs/d6-tools-mcp.md` (hands-on): OPA policy over the MCP tools; **prove an unauthorized/bad-argument tool call is denied** and an **unauthenticated MCP client is rejected** before any tool runs.

## 4. `d6-action-gating` — Autonomous-action zero-trust gating

- [x] 4.1 Write `domains/6-agentic-zero-trust/d6-action-gating.md`: NIST 800-207 PEP/PDP applied to agent **actions**; OPA action-consequentiality classification; LangGraph `interrupt()` approval gate; constrained sandbox for code-exec. Standards: NIST 800-207, OWASP Agentic (excessive agency).
- [x] 4.2 Write `labs/d6-action-gating.md` (hands-on): **prove a consequential action pauses at the `interrupt()` gate** for approval, and that an injected instruction **cannot auto-fire** it.

## 5. `d6-multi-agent` — Multi-agent trust

- [x] 5.1 Write `domains/6-agentic-zero-trust/d6-multi-agent.md`: identity-based (SPIFFE mTLS) peer trust vs. network trust; cascading/wormable injection A→B; a compromise must not launder privilege. Standards: MAESTRO, OWASP Agentic.
- [x] 5.2 Write `labs/d6-multi-agent.md` (hands-on for two local agents; SPIRE federation = walkthrough): two LangGraph agents with SPIFFE mTLS; **prove an unauthenticated peer is rejected** and a poisoned agent **cannot escalate through** the peer.

## 6. `d6-validate` — Red-team the agent

- [x] 6.1 Write `domains/6-agentic-zero-trust/d6-validate.md`: garak/PyRIT against the **action/identity** surface (injection→action, delegated-token authz bypass, confused-deputy, memory poisoning); map each to OWASP-Agentic / ATLAS + the control that stops it. State the boundary vs. `d5-ai-redteam` and cross-link both ways.
- [x] 6.2 Write `labs/d6-validate.md` (hands-on, local target only): fire the agentic attacks at the controls built in §2–5; **each attack is blocked (observable) or documented as a gap** against its technique id. Wire offense from `lab-infra/offense/`.

## 7. Wire the domain into the course

- [x] 7.1 Edit `domains/standards-map.md`: add the agentic offense↔defense↔governance pairing (NIST 800-207/207A, RFC 8693, SPIFFE, MCP auth spec, OWASP Agentic, MAESTRO, ATLAS agentic) as a spine row/section; links per the `resource-citation` standard.
- [x] 7.2 Edit `assessment/data/tracker.yaml`: add the `d6` domain (beyond-blueprint), its five subsections, and per-objective ids/`standards`/`oss`/lab mappings matching sibling-domain density.
- [x] 7.3 Edit `labs/README.md`: add a "Domain 6 — Agentic Zero Trust (beyond-blueprint)" section listing the subsections, labs, hands-on/walkthrough types, and OSS components.
- [x] 7.4 Run `npm run gen:md` to regenerate `assessment/tracker.md` from the updated YAML.

## 8. Verify & finalize

- [x] 8.1 `npm run lint:links` (oss-500) passes over the new Domain 6 content — no host-only/doc-root links except `(reference)`.
- [x] 8.2 `openspec validate add-agentic-zero-trust` passes; spot-check that each spec scenario has a corresponding prove-it observable in a lab.
- [x] 8.3 study-hub: bump the `content/oss-500` submodule, run `npm run lint:content` + `npm test` green, and confirm the new Domain 6 notes/labs render.
- [x] 8.4 No dead links introduced; every Domain 6 subsection can name the standard it implements and the technique that validates it.
