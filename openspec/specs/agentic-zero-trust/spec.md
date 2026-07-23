# agentic-zero-trust Specification

## Purpose

oss-500 stops at defending humans-in-the-loop and chat/RAG AI, but the emerging attack surface is the autonomous agent — a principal that holds its own identity, wields tools, and takes consequential actions. This capability adds a beyond-blueprint Domain 6 that both **builds** agentic zero-trust controls (workload + delegated identity, authorized tool/MCP calls, action gating, identity-based multi-agent trust) and **red-teams** them (injection→action, delegated-token bypass, confused-deputy, memory poisoning). Every control is paired with its defensive standard (NIST SP 800-207/207A, RFC 8693, SPIFFE, the MCP authorization spec) and its offensive/validation standard (OWASP Agentic AI, MAESTRO, MITRE ATLAS agentic techniques), the additions are purely additive to Domains 1–5, and all resource links satisfy the `resource-citation` standard.
## Requirements
### Requirement: Domain 6 — Agentic Zero Trust exists as a beyond-blueprint build-and-prove track
The curriculum SHALL include a new Domain 6, `agentic-zero-trust`, marked `(beyond-blueprint)`, that both **builds** agentic security controls and **red-teams** them. It SHALL comprise five subsections (`d6-identity`, `d6-tools-mcp`, `d6-action-gating`, `d6-multi-agent`, `d6-validate`), each with a note under `domains/6-agentic-zero-trust/` and at least one lab under `labs/d6-*`, and SHALL be wired into `domains/standards-map.md`, `assessment/data/tracker.yaml`, and `labs/README.md`. It SHALL NOT modify the objective ids, labs, or SC-500 exam mappings of Domains 1–5.

#### Scenario: The domain is present and wired in
- **WHEN** the course structure is inspected after this change
- **THEN** `domains/6-agentic-zero-trust/` contains the five subsection notes, `labs/` contains the corresponding `d6-*` labs, and the tracker, standards-map, and labs catalog list Domain 6 as beyond-blueprint

#### Scenario: Domains 1–5 are untouched
- **WHEN** Domains 1–5 are compared before and after this change
- **THEN** their objective ids, existing labs, and exam mappings are unchanged (the addition is purely additive)

### Requirement: An agent has a distinct workload identity and a scoped delegated authority
The `d6-identity` subsection SHALL teach and demonstrate that an agent is a principal with two separate identities: a **workload identity** (a SPIRE-issued SPIFFE SVID for the agent process) and a **delegated authority** to act for a user (a scoped, short-lived OAuth token minted via Keycloak Token Exchange, RFC 8693). The delegated token SHALL be least-privilege and time-limited, not a long-lived agent credential.

#### Scenario: An over-broad or stolen delegated token is refused
- **WHEN** an agent presents a delegated token at a resource for an action outside the token's scope (or a token that has expired)
- **THEN** the resource refuses the request, demonstrating that the delegated authority — not the agent's mere existence — bounds what it can do

#### Scenario: Workload identity is distinct from delegated authority
- **WHEN** the `d6-identity` note and lab are followed
- **THEN** the learner can distinguish the agent's SPIFFE workload identity (who the process is) from its RFC 8693 on-behalf-of token (what it may do for which user), and cite the NIST 800-207 / RFC 8693 / SPIFFE standards behind each

#### Scenario: The SVID mechanics are taught once within Domain 6
- **WHEN** the `d6-identity` and `d6-multi-agent` notes are compared for how each covers SPIFFE SVID mechanics (short-lived and non-exportable, fetched from the SPIRE Workload API, X.509-SVID mTLS vs JWT-SVID bearer, a co-located rogue cannot obtain a peer's SVID)
- **THEN** `d6-identity` (`agent-workload`) SHALL be the single Domain 6 owner of that explanation and `d6-multi-agent` (`agent-mtls`) SHALL reference it rather than restate it, contributing only the net-new agent-to-agent authorization delta (a peer is authorized by its SPIFFE ID rather than by network position, and privilege does not launder across the trust chain), while both notes SHALL preserve their back-link to the Domain 1 canonical `workload-identity.md` (`wi-spiffe`)

### Requirement: Every agent tool and MCP call is authenticated and authorized
The `d6-tools-mcp` subsection SHALL demonstrate an MCP server exposing tools to a LangGraph agent where each tool call is authorized by an OPA policy decision (which identity may call which tool with which arguments) and the MCP server itself authenticates callers (via Keycloak / the MCP authorization spec).

#### Scenario: An unauthorized or malformed tool call is denied
- **WHEN** the agent attempts a tool call its identity is not permitted to make, or with arguments the policy disallows
- **THEN** OPA denies the call and the tool does not execute

#### Scenario: An unauthenticated MCP client is rejected
- **WHEN** a client without a valid credential connects to the MCP server
- **THEN** the connection or tool invocation is rejected before any tool runs

### Requirement: Consequential agent actions are gated by zero-trust approval
The `d6-action-gating` subsection SHALL demonstrate applying the NIST 800-207 PEP/PDP model to agent actions: an OPA policy classifies actions as consequential, and consequential actions are paused for human or deterministic approval using LangGraph's `interrupt()` primitive, with a constrained sandbox for code-execution actions.

#### Scenario: A consequential action pauses for approval
- **WHEN** the agent decides to take an action the policy classifies as consequential
- **THEN** execution halts at the approval gate and the action runs only after explicit approval

#### Scenario: Injection cannot auto-fire a consequential action
- **WHEN** an injected instruction (direct or via tool/retrieved content) attempts to trigger a consequential action
- **THEN** the action is still routed through the approval gate rather than executing autonomously

### Requirement: Multi-agent trust is identity-based, not network-based
The `d6-multi-agent` subsection SHALL demonstrate two or more agents communicating with SPIFFE mTLS peer authentication, and SHALL test cascading / wormable prompt injection from one agent to another. Trust between agents SHALL derive from verified identity, not network location.

#### Scenario: An unauthenticated peer agent is rejected
- **WHEN** an agent receives a request from a peer that cannot present a valid SPIFFE identity
- **THEN** the receiving agent refuses the interaction

#### Scenario: A compromised agent cannot launder privilege
- **WHEN** a poisoned agent attempts to induce a peer to perform an action beyond the peer's own authorization
- **THEN** the peer's own identity/authorization checks stop the escalation (a compromise does not propagate as elevated privilege)

### Requirement: The agent's action and identity surface is offensively validated
The `d6-validate` subsection SHALL red-team the agent's action/identity surface using garak / PyRIT — injection→action, delegated-token authz bypass, confused-deputy via tools, and memory poisoning — mapping each finding to its OWASP-Agentic / MITRE ATLAS technique and the control that should stop it. It SHALL be scoped to the agentic action/identity surface, distinct from and complementary to `d5-ai-redteam` (which targets the chat/RAG guardrail).

#### Scenario: Each attack is blocked or documented as a gap
- **WHEN** an agentic attack (e.g., injection→action or delegated-token bypass) is fired against the built controls
- **THEN** the control either blocks it (and the observable proves the block) or the gap is documented against its OWASP-Agentic / ATLAS technique id

#### Scenario: Scope does not duplicate the Domain 5 chat red-team
- **WHEN** `d6-validate` and `d5-ai-redteam` are compared
- **THEN** `d6-validate` targets the agent's tools/identity/actions while `d5-ai-redteam` targets the chat/RAG guardrail, and each note states the boundary and cross-links the other

### Requirement: Agentic controls are standards-paired in the spine
`domains/standards-map.md` SHALL carry an agentic offense↔defense pairing so each Domain 6 subsection names both the control's defensive standard and the attack/validation standard. The referenced standards SHALL include NIST SP 800-207/207A, RFC 8693, SPIFFE, the MCP authorization spec, OWASP Agentic AI (Threats & Mitigations / Agentic Top 10), MAESTRO, and MITRE ATLAS agentic techniques. All external resource links added by this domain SHALL satisfy the `resource-citation` standard.

#### Scenario: The spine lists the agentic pairing
- **WHEN** `standards-map.md` is read after this change
- **THEN** it includes the agentic control↔attack↔governance mapping and every Domain 6 subsection can cite which standard it implements and which technique validates it

#### Scenario: New links pass the specificity lint
- **WHEN** `npm run lint:links` (oss-500) and `npm run lint:content` (study-hub) run over the new Domain 6 content
- **THEN** they pass — every learning-resource link deep-links to a named section or is marked `(reference)`

### Requirement: Agent SPIRE steps are either deployed or marked directions-only
The Domain 6 agent workload-identity (SPIRE) steps SHALL be either backed by a SPIRE server the `lab-infra/agentic/` component actually deploys, or clearly marked as walkthrough/directions-only — consistent with how the course marks other impractical-to-run pieces. No lab or note SHALL instruct the learner to interact with a SPIRE server (e.g. `exec` into `deploy/spire-server`) that no component deploys, and no lab SHALL claim SPIRE is "reused from Domain 1," where it was covered only as a walkthrough.

#### Scenario: No lab commands a SPIRE server that does not exist
- **WHEN** a learner runs `lab-infra/agentic/up.sh` and starts `labs/d6-identity.md`
- **THEN** either a SPIRE server is deployed and the run-it steps work, or the SVID-issuance steps are marked directions-only — in neither case does a step `exec` into a `spire-server` deployment that was never created

#### Scenario: Labs, notes, and plan agree on SPIRE's status
- **WHEN** a learner compares `labs/d6-identity.md`, `domains/6-agentic-zero-trust/d6-identity.md`, and `plan/phase6-agentic-zero-trust.md`
- **THEN** all three describe SPIRE's deployment status consistently (deployed, or directions-only) with no "already running / reused from Domain 1" claim contradicting the infra docs

#### Scenario: Directions are followable or honestly scoped out
- **WHEN** SPIRE stand-up is left as directions (`lab-infra/agentic/spire/registration.md`)
- **THEN** those directions are either a complete, followable install path, or an honest statement that standing up SPIRE is out of scope for the run-it path — not a single `entry create` command that presupposes an unbuilt server and agent

