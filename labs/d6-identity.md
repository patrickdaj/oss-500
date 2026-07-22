# Lab d6: Agent Delegated Identity — workload SVID vs. scoped on-behalf-of token *(beyond-blueprint)*

Give an agent its **two** identities by hand and prove they're separate: a SPIRE **SVID** (who the process is) and a Keycloak **token-exchange** token (what it may do *for a user*, scoped and short-lived). This is a **guided build** — you enable token exchange, define the scopes, mint the token, register the SVID, and reach the observable: an over-broad or expired delegated token is **refused**, a correctly-scoped one succeeds. Multi-region SPIRE federation is a **walkthrough**.

**Objectives covered**

| id | Objective |
|---|---|
| `agent-workload` | The agent process holds a SPIFFE SVID as its workload identity, distinct from any user token |
| `agent-deleg` | The agent acts for a user only via a scoped, short-lived RFC 8693 on-behalf-of token |

**SC-500 correspondence**: beyond SC-500 (no agentic domain). **Standards**: NIST SP 800-207 (verify identity per request), RFC 8693 (OAuth token exchange), SPIFFE. Managed-identity/service-principal analogues carry over from `d1-workload-identity`.

**Prerequisites**
- Keycloak + SPIRE up from Domain 1 ([`lab-infra/identity`](../lab-infra/identity/)); the `oss500` realm exists. Ollama from `d3-ai` for the agent model.
- The agentic scaffold: [`../lab-infra/agentic/`](../lab-infra/agentic/) (`./up.sh`).
- Notes read: [`../domains/6-agentic-zero-trust/d6-identity.md`](../domains/6-agentic-zero-trust/d6-identity.md); the workload-identity precedent in [`../domains/1-identity-governance/workload-identity.md`](../domains/1-identity-governance/workload-identity.md).

**Estimated time**: 2–3 h · $0 (local) · **local target only**

> **Local only.** Keycloak, SPIRE, and the agent run in your local cluster. Never point token exchange at a hosted IdP or send a real user token off-box.

## Steps

### Part A — the agent's workload identity (`agent-workload`)

1. **Register the agent's SVID yourself** on the SPIRE server (reused from `lab-infra/identity`). Decide the SPIFFE ID first — it names the *process*, not a user:
   ```bash
   kubectl -n oss500-identity exec deploy/spire-server -- \
     /opt/spire/bin/spire-server entry create \
       -spiffeID spiffe://oss500.local/ns/oss500-apps/sa/agent-a \
       -parentID spiffe://oss500.local/ns/oss500-apps/sa/spire-agent \
       -selector k8s:ns:oss500-apps -selector k8s:sa:agent-a
   ```
2. **Prove the SVID is the process's identity, not a user's.** Have the agent fetch its SVID from the Workload API and present it to the MCP server; a process without a valid SVID is rejected. The observable to reach: *workload identity answers "which process," and says nothing about "for which user."* Hold that thought for Part B.

### Part B — scoped delegated authority (`agent-deleg`)

3. **Enable token exchange and scope it — you define the boundary.** Following [`../lab-infra/agentic/keycloak/token-exchange.md`](../lab-infra/agentic/keycloak/token-exchange.md), turn on the preview feature, create the `agent-runtime` client, and define client scopes `read` and `ops:write` bound to the `mcp-tools` audience. The design decision you must make: which scope is default, and which is gated behind the `ops` group? Write it so that a `read` exchange **cannot** yield `ops:write`.
4. **Mint a scoped token and try to overreach.** Exchange a user's token for a `read`-scoped agent token, then attempt a `submit_change` (needs `ops:write`) with it:
   ```bash
   # exchange (fill in from token-exchange.md): grant_type=...token-exchange, subject_token=<user>, scope=read
   # then call the resource with the read-scoped token, asking for a write:
   #   expect: refused — audience/scope mismatch, NOT a 200
   ```
   The observable: **the delegated authority, not the agent, bounds the action.** A `read` token can't write even though it's a perfectly valid token.
5. **Prove the time bound.** Set the exchanged-token lifespan low (e.g. 5 min), wait it out (or mint one already near expiry), and replay it → **401**. A stolen agent token is only useful for minutes.

### Part C — federated trust domains (walkthrough)

6. **Read, don't run.** Two SPIRE trust domains federating SVIDs across clusters needs federated bundle exchange — impractical to stand up fully on one laptop. Trace `federatesWith` and bundle endpoints as a walkthrough; mark it *directions* in your notes.

## Verification
- **`agent-workload`**: the agent presents its SVID and is accepted; a process with no valid SVID is rejected. You can state that the SVID identifies the *process*, independent of any user.
- **`agent-deleg`**: a `read`-scoped exchanged token is **refused** when it attempts a write (scope/audience mismatch), and an **expired** token is refused (401), while a correctly-scoped, unexpired token succeeds.
- You can articulate the two-identity split: SVID = who the process is; delegated token = what it may do, for which user, for how long.

## Reference solution
Build it first; check after. In [`../lab-infra/agentic/`](../lab-infra/agentic/):
- [`keycloak/token-exchange.md`](../lab-infra/agentic/keycloak/token-exchange.md) — the token-exchange client, the `read`/`ops:write` scoping, the short-lifespan setting, and the "prove it" refusals.
- [`spire/registration.md`](../lab-infra/agentic/spire/registration.md) — the SVID entry and the workload-identity observable.
- [`agent/agent.py`](../lab-infra/agentic/agent/agent.py) — the `delegated_token()` exchange call and where the SVID vs. delegated token are used.

If your `read` token could write, your scope/audience binding is too loose. If an expired token still worked, the resource isn't validating expiry — fix it at the resource, not the agent.

## Teardown
```bash
../lab-infra/agentic/down.sh
# revert the agent-runtime client + agent-a SVID entry per the reference docs
# Keycloak + SPIRE stay up (reused by other d6 labs)
```

## Honesty note
**I have not run this stack** — this lab is *directions* (a guided build), not a recording of a passing run. The Keycloak token-exchange config and SPIRE registration are concrete and runnable; the **agent Python is reference scaffolding** on bleeding-edge deps (token exchange is a Keycloak preview feature that moves between versions) — adapt and run it. **Part C (federation) is a walkthrough.** Label anything you did not personally execute as *directions*, and record real results — including "my `read` token could still write" — over a fabricated pass. Same honesty rule as Domain 5.
