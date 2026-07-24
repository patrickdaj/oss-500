# Give an agent a delegated identity *(beyond-blueprint)*

> **Beyond-blueprint.** Domain 6 has no SC-500 mapping — it did not exist in the blueprint, because autonomous, tool-using agents are newer than the exam. It is portfolio-grade enrichment that extends the zero-trust identity thread from Domains 1–2 onto a **new kind of principal**: the agent. Domains 1–4 keep their exam mapping intact; treat this as the "what comes next," not test material.

Domain 6, subsection 1 (`d6-identity`). An autonomous agent is not a user and not an ordinary workload — it is a process that **acts on a user's behalf**, calling tools and other services on its own initiative. That makes it two things at once, and the whole subsection turns on keeping them separate. An agent has a **workload identity** — *who the process is* — which is exactly the SPIFFE/SVID story from [`d1-workload-identity`](../1-identity-governance/workload-identity.md), now attached to an agent pod. And it has a **delegated authority** — *what it may do, for which user* — a scoped, short-lived on-behalf-of token minted per action via **OAuth 2.0 Token Exchange (RFC 8693)**. The agent is a new principal in the trust graph, and the failure mode that defines this subsection is collapsing those two identities into one long-lived, over-broad agent credential — the agent-shaped version of a static service-principal secret.

Primary lab: [d6-identity](../../labs/d6-identity.md). Lab-infra component: [`lab-infra/agentic`](../../lab-infra/agentic/README.md) — it **reuses** the Keycloak realm and SPIRE trust domain already deployed by `lab-infra/identity` (Domain 1) rather than standing up new copies; an agent is just a new registration entry and a new token-exchange client on that existing plane. Multi-region / federated SPIRE trust domains (cross-cluster agent trust) is a **walkthrough** — it needs federated bundles across trust domains that aren't practical to run fully on one laptop host. Sibling notes: [`d6-tools-mcp.md`](d6-tools-mcp.md) (authn/authz on every tool call the delegated token makes) and [`d6-action-gating.md`](d6-action-gating.md) (halting the consequential actions that authority permits). Standards spine: [`../standards-map.md`](../standards-map.md). `agent-deleg` assumes JWT/claim mechanics are already familiar — see [`0-fundamentals/06-oauth-oidc-jwt.md`](../0-fundamentals/06-oauth-oidc-jwt.md) for the token-exchange flow and the `act` actor claim it turns on.

## Give the agent a workload identity separate from its delegated authority

*Objective: `agent-workload` · OSS: SPIFFE/SPIRE SVID ≈ beyond-blueprint: managed-identity for an agent process · Lab: [d6-identity](../../labs/d6-identity.md)*

Start with the identity the agent has *before any user asks it to do anything*: its **workload identity**. This is unchanged from `wi-spiffe` — the agent process runs as a Kubernetes ServiceAccount, and SPIRE issues it a short-lived **SPIFFE SVID** (`spiffe://oss500.local/ns/oss500-apps/sa/agent-a`) after node + workload attestation. The SVID answers exactly one question: *which process is this?* It is minted just-in-time from the Workload API socket, auto-rotated, and never stored — the same "no long-lived credential" property that makes a managed identity safer than a service-principal secret. The agent presents this SVID as its client certificate when it connects to the MCP server (`d6-tools-mcp`) and to peer agents (`d6-multi-agent`), so a process that cannot produce a valid SVID is rejected at the door.

Register the agent's SVID on the SPIRE server that `lab-infra/agentic` deploys (Domain 1 covered SPIFFE/SPIRE only as a walkthrough — this is where SPIRE runs) — no new IdP, just a new entry:

```bash
# On the SPIRE server (deployed by lab-infra/agentic into oss500-identity):
kubectl -n oss500-identity exec statefulset/spire-server -c spire-server -- \
  /opt/spire/bin/spire-server entry create \
    -spiffeID  spiffe://oss500.local/ns/oss500-apps/sa/agent-a \
    -parentID  spiffe://oss500.local/ns/oss500-apps/sa/spire-agent \
    -selector  k8s:ns:oss500-apps \
    -selector  k8s:sa:agent-a
```

The point that carries the whole domain: **the SVID is not authority to act for a user.** It says the process is `agent-a`; it says *nothing* about which user's data `agent-a` may touch right now. An agent that only had a workload identity would be a service that acts as itself — but the entire value of an agent is that it acts *for a user*, with that user's permissions, not the agent's. So the workload identity is necessary (to authenticate the process and secure its transport with mTLS) but deliberately **insufficient**: it must be paired with a *separate* delegated authority (`agent-deleg`) that carries the user context and the scope. Two identities, two questions — *who is the process* vs. *what may it do for whom* — and the lab proves they are physically distinct artifacts (an X.509 SVID vs. a bearer JWT).

Gotchas:
- The SVID is **workload identity, not delegated authority** — presenting a valid SVID does not entitle the agent to any user's resources. Authorization to act for a user comes from the delegated token, evaluated separately at the resource. Conflating them is the core mistake this subsection exists to prevent.
- The SVID is **short-lived and attested**, exactly like `wi-spiffe`: no stored key, auto-rotated, issued only after workload attestation matches the selectors. An agent pod that can't attest gets no identity — the same default-deny as any workload.
- **X.509-SVID (mTLS) vs. JWT-SVID (bearer)** still matters here: the agent uses its X.509-SVID for proof-of-possession mTLS to the MCP server, so a stolen transport identity can't simply be replayed the way a bearer token can.
- Every agent instance is its **own principal** — `agent-a` and `agent-b` get distinct SVIDs so authorization and audit can tell them apart, and one poisoned agent can't impersonate another (the setup for `d6-multi-agent`'s `agent-mtls`).

**Resources:**
- [SPIFFE — the SVID concept (X.509 vs JWT identity documents)](https://spiffe.io/docs/latest/spiffe-about/spiffe-concepts/) `[depth]` (~15 min)
- [RFC 8693 §4.1 — the `act` (actor) claim: how a token names the acting party](https://datatracker.ietf.org/doc/html/rfc8693#section-4.1) `[depth]` (~10 min)

## Delegate scoped, short-lived authority to the agent with OAuth 2.0 Token Exchange

*Objective: `agent-deleg` · OSS: Keycloak Token Exchange (RFC 8693) ≈ beyond-blueprint: OAuth on-behalf-of / delegated identity · Lab: [d6-identity](../../labs/d6-identity.md)*

Now the second identity — the one that makes the agent useful and dangerous. When a user asks the agent to do something, the agent needs to act **with the user's authority, but only for this task, and only for a short while.** The wrong way is to give the agent a standing credential — a client secret or a broad API key it holds forever — and let it call resources as itself. That is the **long-lived-agent-credential anti-pattern**: a static, over-scoped secret that never expires, works for every user, and turns a prompt-injected or compromised agent into a permanent, universal principal. It is the exact agent-shaped rebrand of the service-principal secret that `wi-sa`/`workload-identity` teaches you to eliminate.

The right way is **OAuth 2.0 Token Exchange (RFC 8693)**: the agent presents the *user's* access token and asks Keycloak to mint a **new token that is scoped down, audience-bound, and short-lived** — an on-behalf-of token. The agent never holds a durable credential; it exchanges, per action, for the least authority the action needs. RFC 8693's own framing is **delegation vs. impersonation**: delegation preserves the acting party in the token (the `act` claim — see [`0-fundamentals/06-oauth-oidc-jwt.md`](../0-fundamentals/06-oauth-oidc-jwt.md) for its anatomy — names the agent acting *for* the user), which is what you want — the resource and the audit log can see both "the user" and "via agent-a," not a token that pretends to *be* the user. The exchanged token's authority is bounded by the intersection of the user's own permissions and the requested `scope`/`audience` — the agent can never exchange *up* to more than the user has.

```python
# agent-deleg: RFC 8693 token exchange — user token -> scoped, short-lived agent token.
# The agent NEVER holds a long-lived credential; it exchanges per action for least authority.
def delegated_token(user_token: str, audience: str, scope: str) -> str:
    r = requests.post(
        f"{KEYCLOAK}/protocol/openid-connect/token",
        data={
            "grant_type":        "urn:ietf:params:oauth:grant-type:token-exchange",  # RFC 8693
            "subject_token":     user_token,                                          # act FOR this user
            "subject_token_type":"urn:ietf:params:oauth:token-type:access_token",
            "audience":          audience,     # "mcp-tools" — which resource the token is for
            "scope":             scope,        # "read" (default) vs "ops:write" (privileged)
            "client_id":         os.environ["AGENT_CLIENT_ID"],
            "client_secret":     os.environ["AGENT_CLIENT_SECRET"],  # the actor's own client cred
        },
        timeout=10,
    )
    r.raise_for_status()
    return r.json()["access_token"]     # short-lived (e.g. 5 min), scope-limited, audience-bound
```

Three properties make this a real control, and the lab proves each by making a *refusal* observable:

1. **Scoped (least privilege).** Define client scopes `read` and `ops:write`; grant the agent client exchange-to-`read` by default and `ops:write` *only* for members of the `ops` group. A token minted for `read` **cannot** call the write tool — audience/scope mismatch, refused at the resource. Over-broad exchange fails by construction.
2. **Short-lived (time-bound).** Set the exchanged token lifespan low (e.g. 5 min). A stolen or replayed agent token expires fast; an **expired** token is refused (401) at the resource. The authority evaporates instead of accumulating.
3. **On-behalf-of (delegated, not impersonating).** The token carries the user as subject and the agent as actor, so authorization is evaluated as *"this user, via this agent"* — the agent's existence never widens what the user could do.

Enable it on the reused Domain 1 Keycloak by turning on token exchange for the `agent-runtime` client (Keycloak's standard token exchange implements RFC 8693; the older path is a preview feature gated behind `--features=token-exchange`, the caveat you'll hit if the realm predates it). Because Domain 6 reuses the `d1-idp` realm, `agent-deleg` is *configuration on identity you already run*, not a second IdP — which is the point: the agent slots into the existing zero-trust identity plane as a first-class, but scoped, principal.

Gotchas:
- **The delegated token, not the agent's existence, bounds what it can do.** A valid SVID + a scoped-`read` token = the agent may read, nothing more. Authority lives in the exchanged token's scope/audience and is checked at the resource, every call — never assumed from "it's the agent."
- **Least privilege is per-action, not per-agent.** The agent exchanges for `read` by default and only escalates to `ops:write` when the action needs it *and* the user is entitled — it does not hold a token that can do everything it might ever need.
- **Scope/audience mismatch is refused at the resource, not the agent.** The security boundary is the MCP server / resource validating the token's `aud` and `scope` (`d6-tools-mcp`), so a compromised agent handing itself a bigger scope string still fails — Keycloak won't mint beyond the user's rights, and the resource re-checks.
- **Delegation vs. impersonation (RFC 8693 §1.1).** Prefer delegation — the `act` claim keeps the agent visible in the chain — so the audit trail reads "user X, acting via agent-a," not an opaque token that looks like the user. Impersonation erases the agent from the record and is the wrong default for autonomous actors.
- **Never log the exchanged token or the user's subject token** — both are bearer credentials carrying user context. Redact at the boundary, the same hygiene as `ai-observability`.

**Resources:**
- [RFC 8693 §1.1 — Delegation vs. Impersonation Semantics](https://datatracker.ietf.org/doc/html/rfc8693#section-1.1) `[required-for-quiz]` (~10 min)
- [RFC 8693 §2.1 — the token-exchange request (resource, audience, scope)](https://datatracker.ietf.org/doc/html/rfc8693#section-2.1) `[depth]` (~15 min)
- [Keycloak — Standard token exchange (configuring & using it)](https://www.keycloak.org/securing-apps/token-exchange) `[required-for-lab]` (~20 min)
- [NIST SP 800-207 — Zero Trust Architecture](https://csrc.nist.gov/pubs/sp/800/207/final) (reference — the per-request, least-privilege basis)

## Summary
| Objective | Takeaway |
|---|---|
| `agent-workload` | The agent process is a principal with a **SPIRE SVID** (who it is) — the `wi-spiffe` story on a new kind of workload. The SVID authenticates the process and secures mTLS, but is **not** authority to act for a user; it must be paired with a separate delegated token. |
| `agent-deleg` | The agent acts for a user only via a **scoped, short-lived on-behalf-of token** minted per action with OAuth 2.0 Token Exchange (RFC 8693), bounded by the user's rights × requested scope/audience — the opposite of the long-lived, over-broad agent-credential anti-pattern (a service-principal secret in agent clothing). An over-scoped or expired token is refused *at the resource*. |
