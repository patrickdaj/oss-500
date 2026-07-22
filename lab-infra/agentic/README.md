# lab-infra/agentic — LangGraph agent + MCP + zero-trust controls

The Agentic Zero Trust stack (Domain 6, `d6` → `agent-deleg`, `agent-workload`, `mcp-authz`, `mcp-authn`, `action-gate`, `agent-mtls`, `agent-cascade`, `av-agent-actions`). This domain is **beyond-blueprint** — it builds and red-teams an autonomous, tool-using agent under zero-trust principles. It **reuses** infra already deployed by other domains rather than standing up new copies: Keycloak (`d1-idp`), OPA (`d1-governance`/`d3-ai`), Vault (`d2-secrets`), and the Ollama model server (`d3-ai`). SPIFFE/SPIRE is **not** deployed anywhere — `d1-workload-identity` covers it as a walkthrough — so the agent's workload-identity steps here are **directions** (`spire/registration.md`) that assume a SPIRE server you stand up yourself.

## What this brings up

| Component | Form | Role | Objective |
|---|---|---|---|
| LangGraph agent | Python Deployment/Job | the agent under test — MCP tool-calling, `interrupt()` gate, delegated-token calls | `mcp-authz`, `action-gate` |
| MCP server | Python Deployment | exposes tools to the agent (a safe read tool + a consequential write/exec tool) | `mcp-authn`, `mcp-authz` |
| OPA (tool + action policy) | Deployment/sidecar + ConfigMaps | PDP for every tool call and action-consequentiality decision | `mcp-authz`, `action-gate` |
| Keycloak token-exchange | realm/client config (reuses `d1` Keycloak) | mints scoped, short-lived on-behalf-of tokens (RFC 8693) | `agent-deleg` |
| SPIRE registration | registration entries — **directions** (`d1` covers SPIRE as a walkthrough; no server is deployed) | issues the agent workload SVID; peer mTLS for multi-agent | `agent-workload`, `agent-mtls` |
| Ollama | reused from `d3-ai` (`ClusterIP`) | local model powering the agent (`llama3.2:1b`) | — |

All in **`oss500-apps`**. The model is deliberately tiny (`llama3.2:1b`) so the agent, MCP server, OPA, and Keycloak fit the ~16 GB reference host together.

## Layout

```
agentic/
├── README.md
├── up.sh                       # deploy MCP server, OPA policies, the agent; print run/verify directions
├── down.sh                     # tear down (agent, MCP server, OPA configmaps)
├── agent/
│   ├── agent.py                # LangGraph agent: MCP client + OPA tool-authz + interrupt() gate + token-exchange
│   └── requirements.txt        # langgraph, langchain-mcp-adapters, langchain-ollama, requests
├── mcp-server/
│   └── server.py               # MCP server: lookup (safe) + submit_change (consequential) tools
├── opa/
│   ├── tool-authz.rego         # mcp-authz: who/what/args may call which tool
│   └── action-class.rego       # action-gate: classify an action consequential → requires approval
├── keycloak/
│   └── token-exchange.md       # agent-deleg: enable RFC 8693 token exchange on the d1 realm
└── spire/
    └── registration.md         # agent-workload / agent-mtls: SPIRE entries for the agent SVID(s)
```

## Usage

```bash
cd lab-infra/agentic
./up.sh                 # deploys MCP server + OPA policies + the agent scaffold into oss500-apps
# follow labs/d6-*.md in order (identity → tools-mcp → action-gating → multi-agent → validate)
./down.sh
```

**Prerequisites (reused components must already be up):** `lab-infra/identity` (Keycloak) and `lab-infra/ai` (Ollama). `up.sh` checks for them and fails early with a pointer if they're missing. SPIRE is **not** deployed — its registration steps are directions (see the SPIRE row above and `spire/registration.md`).

## Security model (what each control proves)

- **`agent-deleg`**: the agent acts for a user only via a **scoped, short-lived** Keycloak token-exchange token (RFC 8693). An over-broad or expired token is **refused** at the resource — the delegated authority, not the agent's existence, bounds it.
- **`agent-workload`**: the agent process holds a **SPIRE SVID** — its workload identity, distinct from the user-delegated token.
- **`mcp-authn` / `mcp-authz`**: the MCP server rejects unauthenticated clients; **every** tool call is an OPA allow/deny (identity × tool × args). A disallowed call never reaches the tool.
- **`action-gate`**: OPA classifies an action consequential; consequential actions halt at the LangGraph **`interrupt()`** gate for approval — an injected instruction cannot auto-fire them.
- **`agent-mtls` / `agent-cascade`**: agent-to-agent calls use **SPIFFE mTLS**; a peer without a valid identity is rejected, and a poisoned agent cannot launder privilege through a peer.

## How the labs use this (reference solution, not a hand-out)

**This directory is the reference solution.** The `labs/d6-*.md` don't say "run `up.sh` and watch it pass" — they **guide you to build each control yourself**: they pose the problem, give hints and partial scaffolding, and name the observable you must reach (a refused token, a denied tool call, a paused action). You write the OPA rule, wire the `interrupt()`, attempt the attack. These files are here to **unblock you when stuck and to check your work against** — look after you've tried, not before. Learning is in the building, not the copying.

## Honesty note

The OPA policies, Keycloak token-exchange config, and SPIRE registration are concrete and runnable. The **agent/MCP Python is reference scaffolding** — bleeding-edge (LangGraph / MCP / RFC 8693 token-exchange move fast), so treat `agent.py`/`server.py` as a reference to adapt and run, not pre-verified binaries. Where a lab step is not laptop-runnable (multi-region SPIRE federation), it is marked **walkthrough**. Label anything you did not personally run as *directions* in your notes — the same honesty rule as Domain 5.

## Secrets hygiene

Any generated token-exchange client secret or SPIRE join token is gitignored — only `.example`/`.md` config is committed. Never log raw delegated tokens or prompts (they carry bearer credentials and user context); redact at the boundary, exactly as `ai-observability`.
