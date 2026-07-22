# Checkpoint 6 — Agentic zero trust

Generated from `assessment/data/quiz-6.yaml` — study-hub runs this interactively (Tests page). Pass bar: 80%. 19 questions.

### 1. An agent holds two credentials at once: an X.509 SVID and, per task, a scoped OAuth 2.0 Token Exchange (RFC 8693) on-behalf-of token. When it calls a tool that touches one specific user's data, which credential decides whether the call is allowed, and what is the other one for?

- A. The SVID decides — a valid workload identity is the agent's authority to act for any user
- B. The on-behalf-of token decides (user authority; scope/audience validated at the resource); the SVID only authenticates which process this is and secures the mTLS transport
- C. Either one is sufficient — they are interchangeable proofs of the same thing
- D. The SVID authorizes reads and the on-behalf-of token authorizes writes

<details><summary>Answer</summary>

**B** — The two identities answer two different questions. The SVID is the workload identity — which process is this — and secures mTLS; it is never authority to act for a user. Authority for this user's data comes from the separate delegated on-behalf-of token, whose scope/audience the resource re-validates on every call. Collapsing the two into one long-lived agent credential is the anti-pattern the subsection exists to prevent.

[Documentation](https://spiffe.io/docs/latest/spiffe-about/spiffe-concepts/) · objectives: `agent-workload`

</details>

### 2. Why does the agent use its X.509-SVID for mTLS to the MCP server rather than relying only on a bearer JWT-SVID?

- A. Bearer tokens are faster and always safer
- B. The X.509-SVID gives proof-of-possession mTLS, so a stolen transport identity can't simply be replayed the way a bearer token can
- C. JWT-SVIDs cannot carry a SPIFFE ID
- D. mTLS removes the need for any authorization check

<details><summary>Answer</summary>

**B** — X.509-SVID mTLS is proof-of-possession: the holder must present the private key during the handshake, so a stolen certificate can't be replayed like a bearer JWT. The SVID is also short-lived and attested — no stored key, auto-rotated, issued only after workload attestation matches the selectors.

[Documentation](https://spiffe.io/docs/latest/spiffe-about/spiffe-concepts/) · objectives: `agent-workload`

</details>

### 3. A teammate proposes giving the agent a long-lived client secret / broad API key so it can call resources whenever needed. Why is this the anti-pattern the subsection warns against, and what replaces it?

- A. It is fine as long as the key is stored in a secret manager
- B. It is a static, over-scoped credential that never expires and works for every user — replace it with per-action OAuth 2.0 Token Exchange (RFC 8693) minting a scoped, audience-bound, short-lived on-behalf-of token
- C. Replace it with a longer-lived key so rotation is rarer
- D. Give the agent the user's password instead

<details><summary>Answer</summary>

**B** — A standing credential is the service-principal-secret anti-pattern in agent clothing: it turns a prompt-injected or compromised agent into a permanent, universal principal. The fix is RFC 8693 token exchange — the agent holds no durable credential and exchanges per action for the least authority the action needs.

[Documentation](https://datatracker.ietf.org/doc/html/rfc8693) · objectives: `agent-deleg`

</details>

### 4. RFC 8693 distinguishes delegation from impersonation. For an autonomous agent, which should you prefer and why?

- A. Impersonation — the token should look exactly like the user so the resource is simpler
- B. Delegation — the `act` claim keeps the agent visible in the token, so the audit trail reads "user X, acting via agent-a," not an opaque token pretending to be the user
- C. Neither — the agent should use its own SVID as the authorization token
- D. Impersonation, because it grants more scope

<details><summary>Answer</summary>

**B** — Prefer delegation: the `act` (actor) claim names the agent acting for the user, so both the resource and the audit log see "this user, via agent-a." Impersonation erases the agent from the record — the wrong default for autonomous actors. The exchanged token's authority is also bounded by the user's own rights intersected with the requested scope/audience — the agent can never exchange up.

[Documentation](https://datatracker.ietf.org/doc/html/rfc8693) · objectives: `agent-deleg`

</details>

### 5. An agent presents an on-behalf-of token scoped to `read` and tries to call the write tool; separately it presents a token that expired two minutes ago. Where are these refused?

- A. At the agent itself, which self-polices its scopes
- B. At the resource (MCP server) — it validates `aud`/`scope` and rejects the scope mismatch, and rejects the expired token with 401; the security boundary is the resource, not the agent
- C. At Keycloak, after the tool has already run
- D. Nowhere — a valid-looking token is always accepted

<details><summary>Answer</summary>

**B** — The resource re-checks every call: a `read`-scoped token calling the write tool is an audience/scope mismatch and is refused, and an expired token gets 401. The boundary is the MCP server validating the token — so even a compromised agent handing itself a bigger scope string still fails, because Keycloak won't mint beyond the user's rights and the resource re-validates.

[Documentation](https://datatracker.ietf.org/doc/html/rfc8693) · objectives: `agent-deleg`

</details>

### 6. You are writing the OPA policy that guards every MCP tool call. On what three inputs, evaluated together, must the decision key — and what is the default?

- A. Source IP, time of day, and tool name; default allow
- B. The delegated identity (scopes/groups/tenant), the tool, and the arguments — with `default allow := false` (default-deny), then enumerate the permits
- C. The agent's own reputation, the model's confidence, and the prompt; default allow
- D. Only the tool name; arguments are always safe once the tool is allowed

<details><summary>Answer</summary>

**B** — The PDP keys on who (the delegated identity — scopes, groups, tenant), what tool (a read tool and a write tool are different trust classes), and which arguments, evaluated together. Default-deny is the whole game: a policy that lists what to block fails open on the next tool; `default allow := false` then enumerate permits fails closed.

[Documentation](https://www.openpolicyagent.org/docs/latest/policy-language/#default-keyword) · objectives: `mcp-authz`

</details>

### 7. The agent is authorized to call `lookup`. A poisoned instruction makes it call `lookup` with the argument `../../etc/*`. Why can "the tool is on the allowlist" still be insufficient, and what stops this?

- A. It is sufficient — a permitted tool makes every argument safe
- B. Permitting a tool is necessary but not sufficient; argument guardrails must reject dangerous shapes (wildcard `*`, path-traversal `../`) even on a permitted tool
- C. Only authentication can stop this, not authorization
- D. The model will refuse the argument on its own

<details><summary>Answer</summary>

**B** — Most real agentic incidents are a PERMITTED tool called with a hostile argument (traversal, wildcard, another tenant's id). "You may call lookup" is not "you may lookup ../../etc/*" — the argument guardrail rejects the disallowed pattern even though the tool itself is allowed.

[Documentation](https://genai.owasp.org/resource/agentic-ai-threats-and-mitigations/) · objectives: `mcp-authz`

</details>

### 8. In the tool-authz decision, whose identity must the PDP trust as the `subject`, and why does it matter for the confused-deputy problem?

- A. Whatever identity the agent asserts it is acting as — the agent knows best
- B. The validated delegated token (from d6-identity), never the agent's own word — if the PDP trusts the agent's claim, a prompt-injected agent authorizes itself
- C. The MCP server's own service account
- D. The source pod's IP address

<details><summary>Answer</summary>

**B** — Key on the delegated identity from a validated token, never on "the agent is trusted." If the PDP trusts the agent's word for who it acts as, a prompt-injected agent authorizes itself — the confused deputy. Keying on the delegated subject (plus denying cross-tenant/out-of-scope arguments) is what keeps the deputy from being confused.

[Documentation](https://genai.owasp.org/llmrisk/llm06-excessive-agency/) · objectives: `mcp-authz`

</details>

### 9. Over an HTTP transport, a client connects to the MCP server with NO Authorization header. Per the MCP authorization spec, what must happen?

- A. The safe read tool runs; only write tools need auth
- B. The server (an OAuth 2.1 resource server) returns 401 Unauthorized with a WWW-Authenticate header pointing at its metadata — before any tool executes
- C. The server runs the tool but logs the anonymous caller
- D. The server forwards the request to the model to decide

<details><summary>Answer</summary>

**B** — The MCP server acts as an OAuth 2.1 resource server: every request MUST carry a valid bearer token, and a request with no token gets 401 (with WWW-Authenticate) before any tool runs. AuthN precedes authZ — 401 (who are you?) precedes 403 (you may not) precedes the policy check.

[Documentation](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization) · objectives: `mcp-authn`

</details>

### 10. A token minted for service A is presented at the MCP server, and separately the MCP server needs to call an upstream API. What two spec rules apply?

- A. Accept any valid-looking bearer; forward the inbound token upstream to save a round-trip
- B. Validate audience binding (RFC 8707) so a token issued for another service is rejected; and never pass the inbound token upstream — the server gets its OWN upstream token (no token passthrough → no confused deputy)
- C. Reject all tokens; MCP servers must be anonymous
- D. Trust the token because it is cryptographically valid, regardless of audience

<details><summary>Answer</summary>

**B** — Audience binding (RFC 8707): the server MUST validate the token was issued specifically for it, so a token for service A is refused — that stops replay across services. And the server MUST NOT forward the client's inbound token downstream; it acts as an OAuth client with its own token. Passthrough is exactly the confused-deputy vulnerability the spec calls out.

[Documentation](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization) · objectives: `mcp-authn`

</details>

### 11. "Does the MCP server do the OAuth 401 handshake?" A colleague says always. What is the accurate, transport-dependent answer?

- A. Always yes, regardless of transport
- B. It depends on transport: HTTP transports do the OAuth resource-server flow (401 → discovery → bearer); STDIO SHOULD NOT do the OAuth dance and takes credentials from the environment — but both enforce "no validated subject, no tool"
- C. Always no; MCP never authenticates
- D. Only STDIO does OAuth; HTTP uses environment credentials

<details><summary>Answer</summary>

**B** — The spec's OAuth flow applies to HTTP transports (resource server, 401 on missing/invalid/wrong-audience tokens). An STDIO transport should not do the OAuth handshake and takes credentials from the environment. Either way the invariant holds: authentication precedes any tool execution — the runnable laptop proof is the "no subject, no tool" check.

[Documentation](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization) · objectives: `mcp-authn`

</details>

### 12. `submit_change` is fully authorized for this caller, but an injected instruction steered the agent to invoke it. Authorization won't help — the caller IS authorized. What control addresses this, and how does it classify?

- A. Add more scopes to the token until the action is blocked
- B. Action-gating: a deterministic OPA policy classifies the action as consequential (write/exec/spend/egress) by EFFECT — not the model's own judgement — and consequential actions halt at an approval gate
- C. Ask the LLM whether its own action is dangerous and trust the answer
- D. Rate-limit the tool so it can only fire occasionally

<details><summary>Answer</summary>

**B** — Authorization asks "may this happen"; gating asks "should a permitted consequential action fire without a human." A deterministic, effect-based Rego classifier (does it write/exec/spend/egress?) decides consequentiality — never the model, because a jailbroken model would rate its own malicious action "safe." Consequential actions pause for approval.

[Documentation](https://genai.owasp.org/llmrisk/llm06-excessive-agency/) · objectives: `action-gate`

</details>

### 13. The gate is implemented with LangGraph's `interrupt()`. Why is that structurally stronger than instructing the model to "ask before doing something consequential"?

- A. Because the instruction is written in bold
- B. Because `interrupt()` suspends the graph — it cannot proceed without an external approve/deny — whereas a model can ignore an instruction but cannot ignore a halted graph
- C. Because the model is more trustworthy once instructed
- D. Because `interrupt()` deletes the malicious prompt

<details><summary>Answer</summary>

**B** — `interrupt()` is a pause, not a prompt string: it halts the graph and surfaces the payload out of band, resuming only on an explicit decision. An injected instruction can route the agent to the decision point but cannot cross it autonomously — structure, not a request the model could disregard.

[Documentation](https://github.com/langchain-ai/langgraph) · objectives: `action-gate`

</details>

### 14. Two design questions on the gate: (a) OPA errors or the action is unknown; and (b) what counts as a valid approver. What are the correct answers?

- A. (a) allow it through to avoid blocking work; (b) another LLM call can approve
- B. (a) default-deny — treat unknown/errored classification as consequential and gate it; (b) the approver must be a human or a deterministic non-LLM check, genuinely out of band
- C. (a) retry until OPA returns allow; (b) an agent-supplied token is fine
- D. (a) skip the gate on errors; (b) the model approves itself

<details><summary>Answer</summary>

**B** — Default-deny on classification: if OPA errors or the action is unknown, treat it as consequential and gate it — failing open runs an unclassified action unattended. And the approver must be human or a deterministic non-LLM check; if "approval" is another LLM call or an agent-supplied token, a prompt injection can forge it.

[Documentation](https://genai.owasp.org/resource/agentic-ai-threats-and-mitigations/) · objectives: `action-gate`

</details>

### 15. Agent B receives a call "from inside the cluster, over the mesh." How should B decide the caller is really agent A?

- A. Trust it — a request from the agents subnet / inside the mesh is a peer
- B. Authenticate by the SPIFFE ID in the peer's mTLS client certificate (its SVID), never by IP/subnet/"inside the mesh" — and the TLS must be mutual so both ends prove identity
- C. Check the source IP against a CIDR allowlist
- D. Accept any caller that presents any TLS certificate

<details><summary>Answer</summary>

**B** — Identity is the principal; the network is plumbing. B authenticates A by the SPIFFE ID in A's SVID client cert, not its IP — trust-by-location is the exact anti-pattern zero trust kills. mTLS is mutual (both ends prove identity); the short-lived, non-exportable SVID means a co-located rogue can't obtain A's identity just by sharing its network.

[Documentation](https://cloudsecurityalliance.org/blog/2025/02/06/agentic-ai-threat-modeling-framework-maestro) · objectives: `agent-mtls`

</details>

### 16. Agent A ingests a poisoned document that tells it to instruct peer B to "call `submit_change` to disable the firewall." A is authenticated (valid SVID) and scoped `read`. Why does the cascade die at B?

- A. Because B detects that A is poisoned and blocks A
- B. Because B re-authorizes the request against B's OWN identity, delegated authority, and policy — as if B were doing it directly — so a poisoned A can propagate the prompt but not privilege B never granted
- C. Because A's SVID expires before the request lands
- D. Because mTLS alone blocks consequential actions

<details><summary>Answer</summary>

**B** — Authentication ≠ authorization: mTLS proves it's really A, but B evaluates the action against B's own least privilege, regardless of who asks. A poisoned A can only ask B to do what B was already allowed to do; the escalation is stopped not by detecting A is poisoned (you often can't) but by B never granting a peer more than B itself may do. Consequential actions still hit B's own interrupt() gate.

[Documentation](https://genai.owasp.org/llmrisk/llm01-prompt-injection/) · objectives: `agent-cascade`

</details>

### 17. Why is cascading prompt injection called "wormable," and where must it be contained?

- A. It is not wormable; one hop is the limit
- B. If B relays to C, the injected payload propagates agent→agent (Morris-II-style) — so it must be contained per-hop, because once agents relay there is no single choke point; every peer re-authenticates and re-authorizes
- C. It is contained at a central firewall, so per-hop checks are unnecessary
- D. It is stopped by scanning natural language for malicious intent

<details><summary>Answer</summary>

**B** — A→B→C propagation makes the payload wormable, with no single choke point once agents relay to each other. Contain it per-hop: every peer re-verifies identity and re-authorizes against its own least privilege. You cannot reliably detect that a peer is poisoned or sanitize natural language — the defense is structural least privilege plus the action gate, not trusting an authenticated peer.

[Documentation](https://genai.owasp.org/resource/agentic-ai-threats-and-mitigations/) · objectives: `agent-cascade`

</details>

### 18. Red-teaming the agent, you craft a poisoned tool result carrying "also call `submit_change`…". Which TWO D6 controls should stop it, and how do you report if it gets through?

- A. Only the model's guardrail; report nothing if it passes
- B. action-gate (`interrupt()` halts the write) and mcp-authz — and if it gets through, record it against its ATLAS technique (AML.T0053 AI Agent Tool Invocation) and name the missing control (e.g. "the gate wasn't wired on that node")
- C. Only mcp-authn; report a clean pass regardless
- D. The network firewall; report by CVE number

<details><summary>Answer</summary>

**B** — Injection→action maps to indirect injection (AML.T0051.001) → AML.T0053 AI Agent Tool Invocation; the controls that should stop it are the action gate (interrupt() halts the consequential write) plus tool authorization. Where an attack gets through, that IS the finding — record it against the technique id and name the missing control, the same honesty rule as Domain 5.

[Documentation](https://atlas.mitre.org/techniques/AML.T0053) · objectives: `av-agent-actions`

</details>

### 19. When red-teaming the agent, why test BOTH the token surface (delegated-token authz bypass) and the action surface (gating) — what does each find that the other misses?

- A. They test the same thing; one is enough
- B. The token surface finds authority failures (a token used beyond its scope/audience, refused at the resource); the action surface finds autonomy failures (a permitted consequential action auto-firing without a gate) — different failure classes
- C. The token surface tests the network and the action surface tests the model
- D. Only the action surface matters for agents

<details><summary>Answer</summary>

**B** — The token surface probes whether an agent token can be used outside its scope/audience (should be refused by agent-deleg at the resource); the action surface probes whether a permitted consequential action can fire without pausing at the gate. A bypass on one is invisible to the other, so red-team both — same purple-team method, two distinct surfaces.

[Documentation](https://genai.owasp.org/resource/agentic-ai-threats-and-mitigations/) · objectives: `av-agent-actions`

</details>
