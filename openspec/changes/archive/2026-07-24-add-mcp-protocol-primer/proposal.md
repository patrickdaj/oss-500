# Add an MCP protocol primer before the D6 tools/MCP objective

## Why

Domain 6's `d6-tools-mcp` objective turns entirely on the Model Context Protocol — client/server roles and, decisively, the **transport** (stdio vs streamable HTTP): the whole `mcp-authn` objective (who authenticates, where a bearer token lives, whether OAuth even applies) is a function of transport type. Yet no note teaches MCP before the learner is asked to reason about it (audit P6, line 36; Part 2 D6, line 64). For this persona — strong on protocols but new to agentic/AI — the security lesson lands on an undefined substrate, so the load-bearing MCP authorization spec becomes required reading the note never signals.

## What Changes

- Add an **MCP protocol primer** at the point of first need in `domains/6-agentic-zero-trust/` (in or ahead of the `d6-tools-mcp` note): what an MCP client and server are, the tool-call request/response shape, and the two transports — **stdio** (local, process-bound, no network auth surface) vs **streamable HTTP** (networked, where bearer tokens / OAuth resource-server semantics apply) — made explicit because `mcp-authn` depends on the distinction.
- Tie the primer to the existing "every agent tool and MCP call is authenticated and authorized" requirement so the transport→auth-surface reasoning is anchored, and mark the MCP authorization spec as the load-bearing reference (per `rank-learning-references`).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agentic-zero-trust` — adds a requirement that the MCP protocol (client/server, stdio vs streamable-HTTP transport) is taught before the `d6-tools-mcp` / `mcp-authn` objective reasons about it, so the transport-dependent authorization lesson stands on defined terms.

## Impact

- Affected specs: `agentic-zero-trust` (one ADDED requirement).
- Affected content (at implementation time): the `d6-tools-mcp` note under `domains/6-agentic-zero-trust/` gains a short MCP primer; the MCP authorization spec link is tagged load-bearing.
- Unblocks `mcp-authn` for a learner new to MCP.
