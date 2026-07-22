"""Minimal MCP server for the Agentic Zero Trust labs.

Exposes two tools so the labs can prove the trust boundary:
  - lookup(query)        : SAFE, read-only. Requires a token scoped to "read".
  - submit_change(tenant, payload) : CONSEQUENTIAL. Requires "ops" group + own tenant,
                                      and is routed through the agent's approval gate.

mcp-authn: the server rejects an unauthenticated client (no valid bearer) before any tool runs.
mcp-authz: the server (and/or the agent) calls OPA (opa/tool-authz.rego) for every tool call.

Reference scaffolding — bleeding-edge SDK; complete + run per labs/d6-tools-mcp.md.
"""
from mcp.server.fastmcp import FastMCP  # pip install mcp
import os
import requests

OPA = os.environ.get("OPA_URL", "http://localhost:8181/v1/data/agentic/tools")
mcp = FastMCP("agentic-tools")


def _authz(subject: dict, tool: str, args: dict) -> None:
    """mcp-authz: ask OPA; raise if denied. Default-deny on any OPA error."""
    r = requests.post(OPA, json={"input": {"subject": subject, "tool": tool, "args": args}}, timeout=5)
    result = r.json().get("result", {})
    if not result.get("allow", False):
        raise PermissionError("; ".join(result.get("deny", ["denied by policy"])))


@mcp.tool()
def lookup(query: str, subject: dict) -> str:
    """SAFE read tool. subject is the validated delegated-token claims."""
    _authz(subject, "lookup", {"query": query})
    return f"result for {query!r}"


@mcp.tool()
def submit_change(tenant: str, payload: str, subject: dict) -> str:
    """CONSEQUENTIAL write tool. Authz here; the agent still gates it via interrupt()."""
    _authz(subject, "submit_change", {"tenant": tenant, "payload": payload})
    return f"change submitted to {tenant}"


if __name__ == "__main__":
    # mcp-authn: run behind an authenticating transport (OAuth per the MCP authorization spec);
    # unauthenticated clients are rejected before reaching a tool. See labs/d6-tools-mcp.md.
    mcp.run()
