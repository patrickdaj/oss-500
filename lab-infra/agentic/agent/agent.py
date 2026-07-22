"""LangGraph agent for the Agentic Zero Trust labs — reference scaffolding.

Shows WHERE the zero-trust hooks go, so the security control is legible:
  agent-deleg   : mint a scoped, short-lived on-behalf-of token via Keycloak token exchange (RFC 8693)
  agent-workload: present the agent's own SPIRE SVID (workload identity) — separate from the user token
  mcp-authz     : every MCP tool call carries the delegated subject; OPA allow/deny (in the MCP server)
  action-gate   : a consequential action pauses at interrupt() for approval before it runs

Bleeding-edge deps (LangGraph / langchain-mcp-adapters move fast) — complete + run per labs/d6-*.md.
"""
import os
import requests
from langgraph.prebuilt import create_react_agent
from langgraph.types import interrupt
from langchain_ollama import ChatOllama
from langchain_mcp_adapters.client import MultiServerMCPClient

KEYCLOAK = os.environ["KEYCLOAK_URL"]        # reused d1 Keycloak
OPA_ACTIONS = os.environ.get("OPA_ACTIONS_URL", "http://localhost:8181/v1/data/agentic/actions")


def delegated_token(user_token: str, audience: str, scope: str) -> str:
    """agent-deleg: RFC 8693 token exchange — user token -> scoped, short-lived agent token.

    The agent NEVER holds a long-lived credential; it exchanges the user's token for a
    least-privilege, time-limited token bounded to `scope` on `audience`.
    """
    r = requests.post(
        f"{KEYCLOAK}/protocol/openid-connect/token",
        data={
            "grant_type": "urn:ietf:params:oauth:grant-type:token-exchange",
            "subject_token": user_token,
            "subject_token_type": "urn:ietf:params:oauth:token-type:access_token",
            "audience": audience,
            "scope": scope,
            "client_id": os.environ["AGENT_CLIENT_ID"],
            "client_secret": os.environ["AGENT_CLIENT_SECRET"],
        },
        timeout=10,
    )
    r.raise_for_status()
    return r.json()["access_token"]


def gate(action: dict) -> None:
    """action-gate: ask OPA if the action is consequential; if so, pause for approval."""
    result = requests.post(OPA_ACTIONS, json={"input": {"action": action}}, timeout=5).json().get("result", {})
    if result.get("requires_approval", True):        # default-deny: unknown -> require approval
        decision = interrupt({"approve": result.get("reason", "consequential action"), "action": action})
        if decision != "approve":
            raise PermissionError(f"action refused at approval gate: {action}")


async def build_agent(user_token: str):
    # agent-workload: the process authenticates to the MCP server with its SPIRE SVID (mTLS);
    # agent-deleg: it carries the exchanged, scoped delegated token as the acting subject.
    agent_token = delegated_token(user_token, audience="mcp-tools", scope="read")
    client = MultiServerMCPClient({
        "tools": {"transport": "streamable_http", "url": os.environ["MCP_URL"],
                  "headers": {"Authorization": f"Bearer {agent_token}"}},
    })
    tools = await client.get_tools()
    llm = ChatOllama(model=os.environ.get("OLLAMA_MODEL", "llama3.2:1b"),
                     base_url=os.environ["OLLAMA_URL"])
    # The react agent calls tools; wrap consequential tool nodes so gate() runs first
    # (see labs/d6-action-gating.md for the interrupt() wiring around submit_change).
    return create_react_agent(llm, tools)
