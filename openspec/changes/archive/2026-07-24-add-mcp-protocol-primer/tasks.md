# Tasks — add-mcp-protocol-primer

## 1. Write the MCP primer

- [x] 1.1 In the `d6-tools-mcp` note under `domains/6-agentic-zero-trust/`, add a short MCP primer: client/server roles and the tool-call request/response shape.
- [x] 1.2 Contrast the two transports explicitly — **stdio** (local, process-bound, no network auth surface) vs **streamable HTTP** (networked, bearer-token / OAuth resource-server semantics) — and state that the `mcp-authn` design depends on which transport is in use.

## 2. Anchor and rank references

- [x] 2.1 Tie the primer to the existing "every agent tool and MCP call is authenticated and authorized" teaching so the transport→auth-surface reasoning is anchored.
- [x] 2.2 Tag the MCP authorization spec link as load-bearing (`required-for-lab`/`required-for-quiz`) per `rank-learning-references`.

## 3. Validation

- [x] 3.1 Run `openspec validate add-mcp-protocol-primer --type change --strict`.
