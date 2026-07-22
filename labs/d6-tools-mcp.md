# Lab d6: Tool / MCP Trust Boundaries — authorize every call, authenticate every caller *(beyond-blueprint)*

Make the agent's tool surface a real trust boundary. This is a **guided build** — you write the OPA `tool-authz` policy yourself and wire it onto the MCP call path, then reach two observables: an **unauthorized or bad-argument tool call is denied**, and an **unauthenticated MCP client is rejected before any tool runs**. Check against the reference solution after you've built it. The full OAuth-over-HTTP transport is a **walkthrough**; the "no subject, no tool" check is runnable.

**Objectives covered**

| id | Objective |
|---|---|
| `mcp-authz` | Every MCP tool call is a default-deny OPA decision on identity × tool × arguments |
| `mcp-authn` | The MCP server rejects an unauthenticated/wrong-audience client before a tool executes |

**SC-500 correspondence**: beyond SC-500. **Standards**: MCP authorization specification (OAuth 2.1 resource server, RFC 8707 audience binding), OWASP Agentic AI — Threats & Mitigations, OWASP `LLM06` Excessive Agency, NIST 800-207 (PEP/PDP). Defensive control: OPA on the tool call path + MCP authn.

**Prerequisites**
- The agentic scaffold: [`../lab-infra/agentic/`](../lab-infra/agentic/) (`./up.sh` deploys the MCP server + OPA into `oss500-apps`). A scoped delegated token from [`d6-identity`](d6-identity.md).
- Notes read: [`../domains/6-agentic-zero-trust/d6-tools-mcp.md`](../domains/6-agentic-zero-trust/d6-tools-mcp.md); the OPA-at-the-gateway precedent in [`../domains/3-compute-ai/ai-security.md`](../domains/3-compute-ai/ai-security.md) (`ai-governance`).

**Estimated time**: 2–3 h · $0 (local) · **local target only**

> **Local only.** The MCP server, OPA, and agent run in your local `oss500-apps`.

## Steps

### Part A — write the tool-authorization policy (`mcp-authz`)

1. **Start from default-deny — you write the rules.** Create a Rego policy in package `agentic.tools` with `default allow := false`, then add exactly the permits the tools need. The design decisions are yours: which scope unlocks the *safe* read tool, and what two conditions gate the *consequential* write tool? Sketch it before coding:
   ```
   allow lookup        if subject scoped to "read"
   allow submit_change if subject in group "ops" AND args.tenant == subject.tenant   # no cross-tenant
   ```
2. **Add an argument guardrail.** A permitted tool is not a blank cheque — reject a wildcard (`*`) or path-traversal (`../`) in *any* argument, even for an allowed tool. Write the `deny` rule that matches those patterns.
3. **Wire it on the call path.** Make the MCP server (or the agent's MCP client) call OPA with `{subject, tool, args}` before executing a tool, and **fail closed** if OPA errors. The subject must come from the *validated delegated token* (`d6-identity`), never from the agent's own assertion.

### Part B — prove denial (`mcp-authz`)

4. **Fire three calls and compare** — reach the observable that a disallowed combination never touches the tool body:
   - `lookup` with a `read`-scoped token → **allowed**.
   - `submit_change` with a `read`-scoped (non-`ops`) token → **denied** (wrong identity).
   - `lookup` with argument `../../etc/*` → **denied** by the guardrail (permitted tool, hostile argument).
   ```bash
   # e.g. drive the agent/MCP client with each case and read the decision + OPA reason
   kubectl -n oss500-apps logs deploy/agent-a | grep -E 'tool=|allow|deny'
   ```
   Note *why* each denial happened (identity vs. argument), not just that it did.

### Part C — reject the unauthenticated caller (`mcp-authn`)

5. **Prove authN precedes authZ.** Call the MCP server with **no validated subject / no bearer** and confirm the tool refuses to run *before* any policy check — "no subject, no tool." This is the runnable core of `mcp-authn`.
6. **Reason through the OAuth transport (walkthrough).** Per the MCP authorization spec, an HTTP-transport MCP server is an OAuth 2.1 resource server: no token → **401 + `WWW-Authenticate`**, wrong-audience token → 401 (RFC 8707), and it **must not** pass the caller's token upstream (confused deputy). The reference runs on stdio, so trace the 401 handshake against the spec and put an authenticating proxy in front — mark it *directions*.

## Verification
- **`mcp-authz`**: a `read` token can `lookup` but not `submit_change`; a permitted tool with a `*`/`../` argument is denied; every denial has an OPA reason and the tool body never ran. Default-deny holds for an unlisted tool.
- **`mcp-authn`**: a caller with no validated subject is refused before any tool executes; you can describe the full OAuth-401 + audience-binding flow the HTTP transport would enforce.

## Reference solution
Build the policy yourself first; check after. In [`../lab-infra/agentic/`](../lab-infra/agentic/):
- [`opa/tool-authz.rego`](../lab-infra/agentic/opa/tool-authz.rego) — the complete policy: default-deny, the two `allow` rules, and the wildcard/traversal argument guardrail.
- [`mcp-server/server.py`](../lab-infra/agentic/mcp-server/server.py) — `_authz()` calling OPA (fail-closed) and the safe/consequential tools; the transport note for `mcp-authn`.

If your policy denies by *listing what to block*, it fails open on the next tool — invert it to allow-listing. If the tool trusted the agent's word for the subject, a prompt-injected agent authorizes itself — key on the validated token.

## Teardown
```bash
../lab-infra/agentic/down.sh    # removes the agent, MCP server, OPA configmaps
```

## Honesty note
**I have not run this stack** — this lab is *directions* (a guided build). The OPA policy and the "no subject, no tool" check are concrete and runnable; the **MCP server/agent Python is reference scaffolding** on fast-moving SDKs — adapt and run. **The full OAuth-over-HTTP transport is a walkthrough.** Label anything you did not personally execute as *directions*; record a real gap ("`submit_change` ran for a read token — I keyed authz on the tool name only") over a fabricated pass. Same honesty rule as Domain 5.
