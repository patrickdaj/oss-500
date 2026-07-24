# Secure the tool surface — MCP trust boundaries *(beyond-blueprint)*

> **Beyond-blueprint.** SC-500 is a cloud-and-AI *defensive* exam; it does not cover autonomous agents, tool-calling, or the Model Context Protocol. Domain 6 is expanded, portfolio-grade enrichment — it builds and red-teams a tool-using agent under zero-trust principles, extending the controls from Domains 1–4 (identity, OPA, mTLS) onto the agent. Domains 1–4 keep their exam mapping intact; treat this domain as the frontier that follows from them.

Domain 6, subsection `d6-tools-mcp` (tools / MCP). An agent's power *is* its tools: the moment an LLM can call a tool it can **act**, and the tool surface is where a prompt-injected or over-scoped agent turns words into consequences (a write, a payment, a shell). **MCP — the Model Context Protocol** — is the emerging standard by which an agent (the MCP *client*) discovers and calls tools exposed by an MCP *server* over a client/server transport. That server-to-agent boundary is a **trust boundary**: every tool call crossing it is untrusted input to a privileged action until proven otherwise. Two controls make it a real boundary rather than an implicit "the model decides" — **authorize** every call (`mcp-authz`) and **authenticate** the caller (`mcp-authn`). This is the same PEP/PDP zero-trust posture as the rest of the course (NIST SP 800-207), pushed down to the tool call.

Primary lab: [d6-tools-mcp](../../labs/d6-tools-mcp.md). Lab-infra component: [`lab-infra/agentic`](../../lab-infra/agentic/) — a LangGraph agent, an MCP server exposing a *safe* read tool (`lookup`) and a *consequential* write tool (`submit_change`), and an OPA policy (`opa/tool-authz.rego`) consulted on every call. It **reuses** the OPA engine from `d3-ai`/`d1-governance` and the delegated identity from [`d6-identity`](d6-identity.md) rather than standing up new copies. The identity these decisions key on comes from `d6-identity` (a scoped, short-lived delegated token); the *consequentiality* gate that pauses a permitted write for approval is [`d6-action-gating`](d6-action-gating.md). The `mcp-authn` OAuth transport is partly a **walkthrough** — the SDKs move fast (see the Honesty notes), so the authenticating transport is reasoned/configured while the OPA authorization and the "no subject, no tool" check are runnable. Standards throughout: the **MCP authorization specification** and **OWASP Agentic AI — Threats & Mitigations**; see [`../standards-map.md`](../standards-map.md) for the offense↔defense spine.

## MCP protocol primer — client, server, transport, tool call

Before reasoning about *authorizing* or *authenticating* an MCP call, pin down the terms. **MCP client** — code embedded in the agent's host application (here, the LangGraph agent) that discovers and invokes tools. **MCP server** — a separate process that exposes those tools (and optionally resources/prompts) over JSON-RPC 2.0. The client first calls `tools/list` to discover what's available — each tool's name, description, and a JSON-Schema input shape — then invokes one with `tools/call`:

```
→ {"method": "tools/call", "params": {"name": "submit_change", "arguments": {"tenant": "acme", "payload": "..."}}}
← {"content": [{"type": "text", "text": "queued"}], "isError": false}
```

That request/response pair is the exact boundary the rest of this note defends: `mcp-authz` (below) decides whether *this* `tools/call` — this identity, this tool, these arguments — is permitted; `mcp-authn` decides whether the client sending it is even a known caller.

The client and server exchange those messages over one of two **transports**, and the transport is not incidental plumbing — it fixes the entire authentication design:

- **stdio** — the server runs as a local subprocess; the client writes JSON-RPC to its stdin and reads replies from its stdout. There is no network hop, so there is no bearer token to steal, forge, or replay in transit — the process boundary (who can spawn or pipe to the server) *is* the trust boundary. The MCP spec accordingly says an stdio server SHOULD NOT run the OAuth flow and should instead take credentials from its environment.
- **streamable HTTP** — the server listens on a network port and the client POSTs JSON-RPC over HTTP. A network caller is unauthenticated by default, so the MCP authorization specification requires the server behave as an OAuth 2.1 **resource server**: every request carries `Authorization: Bearer <token>`, audience-bound (RFC 8707) to this server specifically.

This is why `mcp-authn`, below, has no single answer to "does the MCP server do OAuth?" — the answer is **"it depends which transport is in use."** The reference lab server (`lab-infra/agentic/mcp-server/server.py`) runs on stdio, which is exactly why the OAuth-401 handshake is a walkthrough there rather than something you run and observe.

This is the protocol-level version of the domain's standing rule — **every agent tool and MCP call is authenticated and authorized** (`agentic-zero-trust`) — made concrete: `mcp-authz` is the per-`tools/call` policy decision, `mcp-authn` is the transport-dependent gate in front of it. The **MCP authorization specification** is the load-bearing reference for the latter (tagged in its Resources list below) — the resource-server role, the audience binding, and the no-passthrough rule are specific to MCP, not something to infer from OAuth flows you already know.

## Authorize every tool call — default-deny on identity × tool × arguments

*Objective: `mcp-authz` · OSS: OPA on the MCP call path ≈ beyond-blueprint (extends the `d3-ai` OPA-at-the-gateway pattern down to tools) · Lab: [d6-tools-mcp](../../labs/d6-tools-mcp.md)*

The `ai-governance` objective put OPA at the *model* gateway — one allow/deny per inference. Agentic systems move the risk down a layer: the model no longer just answers, it emits **tool calls**, and a single poisoned instruction ("also submit a change deleting tenant X") can make it invoke a state-changing tool with attacker-chosen arguments. So the same policy-decision pattern has to wrap **every tool call**, not just the prompt. The MCP server (or the agent's MCP client) is the **PEP**; OPA is the **PDP**; the decision is keyed on three things, evaluated together:

- **who** — the delegated identity: its `scopes`, `groups`, `tenant` (carried by the `d6-identity` token, not asserted by the agent itself);
- **what tool** — `lookup` vs `submit_change`; a read tool and a write tool are not the same trust class;
- **which arguments** — the tool being permitted does **not** make every argument safe.

Two rules make this a boundary. First, **default-deny**: an identity × tool × argument combination that isn't explicitly allowed is refused — a new tool, an unknown caller, or a caller reaching outside its scope gets nothing. Second, **argument guardrails**: even a permitted tool must reject dangerous argument shapes — a wildcard (`*`) or a path-traversal (`../`) target — because "you may call `lookup`" is not "you may `lookup` `../../etc/*`". If the `deny contains msg if { … }` shape below isn't already familiar, the [D1 `governance` note's Rego primer](../1-identity-governance/governance.md#rego--the-language-every-policy-below-is-written-in) teaches it — this note reuses the language, not re-teaches it. A representative policy (the *pattern*, not the full lab solution):

```rego
package agentic.tools

default allow := false   # unlisted identity/tool/arg combo → refused

# safe read tool: any caller whose delegated token is scoped to "read"
allow if {
    input.tool == "lookup"
    "read" in input.subject.scopes
}

# consequential write tool: only the "ops" group, only the caller's own tenant
allow if {
    input.tool == "submit_change"
    "ops" in input.subject.groups
    input.args.tenant == input.subject.tenant   # no cross-tenant writes
}

# argument guardrail: reject wildcard/traversal even on a permitted tool
deny contains msg if {
    some k
    regex.match(`(\*|\.\.\/)`, sprintf("%v", [input.args[k]]))
    msg := sprintf("argument %q has a disallowed pattern", [k])
}
```

The agent sends `{subject, tool, args}` as `input`; OPA returns `allow` plus `deny` reasons; a disallowed call **never reaches the tool body**, and the reason is logged for audit. The three agentic threats this defends against — name them:

- **Tool-description poisoning** — an MCP tool's *description* (which the model reads to decide when/how to call it) is attacker-controlled content. A malicious or compromised server can describe a tool so the agent passes it secrets or calls it unprompted. Default-deny + argument guardrails limit the blast radius: even a persuaded agent can't invoke a tool it isn't authorized for, with arguments the policy forbids.
- **Over-broad tool scopes** — a tool granted more capability than the task needs (a `submit_change` reachable by every caller, a filesystem tool with no path restriction). This is **OWASP LLM06 Excessive Agency** at the tool layer; least privilege per tool, per identity, is the fix.
- **Confused-deputy** — the agent holds real privilege, so an attacker who can steer it borrows that privilege. Keying the decision on the *delegated* identity (not the agent's own standing authority) and denying cross-tenant/out-of-scope arguments is what stops the deputy being confused.

Gotchas:
- **Default-deny is the whole game.** A policy that lists what to *block* fails open on the next tool you add; a policy that lists what to *allow* fails closed. `default allow := false`, then enumerate permits.
- **Authorize arguments, not just the tool name.** Most real agentic incidents are a *permitted* tool called with a hostile argument (traversal, wildcard, another tenant's id). The tool being on the allowlist is necessary, not sufficient.
- **Key on the delegated identity, never on "the agent is trusted."** If the PDP trusts the agent's word for who it's acting as, a prompt-injected agent authorizes itself. The subject must come from a validated token (`d6-identity`).
- **Authorization ≠ consequentiality.** `mcp-authz` decides *may this call happen*; `d6-action-gating` decides *should a permitted consequential call pause for human approval*. `submit_change` is authorized here **and** gated there — two independent controls.

**Resources:**
- [Open Policy Agent — Rego "Default Keyword" (default-deny complete rules)](https://www.openpolicyagent.org/docs/latest/policy-language/#default-keyword) `[depth]` (~15 min)
- [OWASP Agentic AI — Threats & Mitigations (Tool Misuse & Exploitation)](https://genai.owasp.org/resource/agentic-ai-threats-and-mitigations/) `[depth]` (~30 min)
- [OWASP LLM06: Excessive Agency (over-broad tool scopes)](https://genai.owasp.org/llmrisk/llm06-excessive-agency/) `[depth]` (~15 min)
- [MCP specification — Access Token Privilege Restriction (confused deputy / token passthrough)](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization#access-token-privilege-restriction) `[depth]` (~15 min)

## Authenticate the MCP client before any tool runs

*Objective: `mcp-authn` · OSS: MCP server as an OAuth 2.1 resource server ≈ beyond-blueprint · Lab: [d6-tools-mcp](../../labs/d6-tools-mcp.md) (OAuth transport is a walkthrough)*

Authorization only means something if you **know the caller**. `mcp-authz` answers "may this identity call this tool" — but an anonymous or forged caller makes that question unanswerable, so authentication has to come *first*: no tool runs for a client you can't identify. The **MCP authorization specification** defines exactly this for HTTP transports: the MCP server acts as an **OAuth 2.1 resource server**. It advertises its authorization server via OAuth 2.0 Protected Resource Metadata (RFC 9728), and every request **MUST** carry a valid `Authorization: Bearer <token>`. A request with **no** token gets **HTTP 401 Unauthorized** (with a `WWW-Authenticate` header pointing the client at the metadata) — *before* any tool executes. An invalid, expired, or wrong-audience token is likewise rejected 401; insufficient scope is 403.

```
Client ──(no token)──▶ MCP server ──▶ 401 Unauthorized + WWW-Authenticate   (no tool runs)
Client ──(OAuth 2.1 flow: discover AS, PKCE, resource-bound token)──▶ Authorization Server
Client ──Authorization: Bearer <token for THIS server>──▶ MCP server ─validate→ tool authz (mcp-authz)
```

The security details that matter (all from the spec, and all agentic-relevant):

- **Audience binding (RFC 8707).** The server **MUST** validate that the token was issued *specifically for it* — the `resource` parameter binds the token to this MCP server. A token minted for service A must not be accepted at the MCP server; that's the boundary that stops token replay across services.
- **No token passthrough → no confused deputy.** If the MCP server calls upstream APIs, it acts as an OAuth *client* to them with a *separate* token; it **MUST NOT** forward the client's inbound token downstream. Passing the token through is precisely the **confused-deputy** vulnerability the spec calls out — the downstream API trusts a token it shouldn't.
- **Short-lived tokens.** The authorization server should issue short-lived access tokens, dovetailing with the scoped, short-lived *delegated* token from [`d6-identity`](d6-identity.md) — the caller's authority is bounded in both scope and time.

Transport caveat (why the lab marks part of this a **walkthrough**): the spec's OAuth flow applies to **HTTP-based** transports; an **STDIO** transport **SHOULD NOT** do the OAuth dance and instead takes credentials from the environment. The reference MCP server runs on the default (stdio) transport, so the *runnable* proof on a laptop is the **"no validated subject, no tool"** check — the tool refuses to run when the caller's identity is absent/unverified — while the full OAuth-401 handshake over HTTP is reasoned through against the spec (put an authenticating proxy or an HTTP transport in front). Both express the same invariant: **authentication precedes any tool execution.**

Gotchas:
- **AuthN before authZ, always.** Rejecting the unauthenticated client is step zero; a beautiful OPA policy is worthless if an anonymous client can reach the tool at all. 401 (who are you?) precedes 403 (you may not) precedes the policy check.
- **Audience-bind the token.** Accepting any valid-looking bearer — regardless of who it was issued *for* — is the classic MCP mistake; validate the audience/`resource` so a token for another service can't be replayed here.
- **Never pass the client's token upstream.** The MCP server gets its *own* upstream token; forwarding the inbound one is token passthrough and re-creates the confused deputy. This is an explicit spec `MUST NOT`.
- **STDIO vs HTTP changes the answer.** "Does the MCP server do OAuth?" depends on transport — HTTP: yes (resource server); STDIO: no (environment credentials). Know which transport the scenario uses.

**Resources:**
- [MCP specification — Authorization: Token Handling (OAuth 2.1 resource server, 401 on invalid)](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization#token-handling) `[required-for-lab]` (~25 min)
- [MCP specification — Authorization Flow overview (401 → discovery → bearer token)](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization#authorization-flow) `[depth]` (~15 min)
- [MCP specification — Confused Deputy Problem (security best practices)](https://modelcontextprotocol.io/specification/2025-06-18/basic/security_best_practices#confused-deputy-problem) `[depth]` (~15 min)
- [OWASP Agentic AI — Threats & Mitigations (identity & privilege abuse)](https://genai.owasp.org/resource/agentic-ai-threats-and-mitigations/) (reference — agentic threat taxonomy)

## Reference solution

The lab **guides you to build** the policy and wire the call yourself — pose the problem, write the Rego, reach the observable. Check your work against the reference solution **after** you've tried, not before:

- [`lab-infra/agentic/opa/tool-authz.rego`](../../lab-infra/agentic/opa/tool-authz.rego) — the complete `mcp-authz` policy: default-deny, the two `allow` rules (read scope; ops-group + own-tenant), and the wildcard/traversal argument guardrail.
- [`lab-infra/agentic/mcp-server/server.py`](../../lab-infra/agentic/mcp-server/server.py) — the MCP server: `_authz()` calls OPA and raises on deny (default-deny on any OPA error), the two tools (`lookup` safe / `submit_change` consequential), and the `mcp.run()` transport note for `mcp-authn`.
- [`lab-infra/agentic/README.md`](../../lab-infra/agentic/README.md) — the security model and how the reused components (OPA, Keycloak, SPIRE, Ollama) fit.

## Summary
| Objective | Takeaway |
|---|---|
| `mcp-authz` | Every MCP tool call is a default-deny OPA decision keyed on identity × tool × arguments; argument guardrails reject wildcard/traversal even on a permitted tool. Defends tool-description poisoning, over-broad scopes (LLM06), and confused-deputy — the `d3-ai` gateway pattern pushed down to tools. |
| `mcp-authn` | The MCP server is an OAuth 2.1 resource server: an unauthenticated or wrong-audience client is rejected (401) before any tool runs; no token passthrough upstream (confused deputy). AuthN precedes authZ. OAuth transport is a walkthrough; the "no subject, no tool" check is runnable. |
