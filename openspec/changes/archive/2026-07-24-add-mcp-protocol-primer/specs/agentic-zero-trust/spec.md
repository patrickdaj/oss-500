## ADDED Requirements

### Requirement: The MCP protocol is taught before its authorization is reasoned about

The `d6-tools-mcp` note SHALL teach the Model Context Protocol before the learner is asked to reason about `mcp-authn`. The primer SHALL cover: the client/server roles, the tool-call request/response shape, and — decisively — the two transports, **stdio** (local, process-bound, no network authentication surface) versus **streamable HTTP** (networked, where bearer-token / OAuth resource-server semantics apply). The note SHALL make explicit that the authentication and authorization design for an MCP call depends on the transport, and SHALL mark the MCP authorization spec as a load-bearing reference (per the necessity-tag standard).

#### Scenario: The transport distinction is defined before it is used

- **WHEN** a learner reaches the `mcp-authn` objective in `d6-tools-mcp`
- **THEN** the note has already defined MCP client/server and the stdio-vs-streamable-HTTP transports, so the learner can reason about where a token lives and whether OAuth applies from course material rather than from the external spec

#### Scenario: The load-bearing MCP reference is signalled

- **WHEN** a learner reads the `d6-tools-mcp` resource list
- **THEN** the MCP authorization spec is tagged as required reading (not one anonymous link among several), so the learner knows it is the load-bearing source for the objective
