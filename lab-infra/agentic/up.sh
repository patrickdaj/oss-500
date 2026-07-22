#!/usr/bin/env bash
# Bring up the Agentic Zero Trust stack: MCP server + OPA (tool + action policy) + LangGraph agent.
# Reuses Keycloak (lab-infra/identity) and Ollama (lab-infra/ai) — does NOT redeploy them.
# SPIRE is not deployed by any component; its registration steps are directions (see spire/registration.md).
# Objectives: agent-deleg, agent-workload, mcp-authn, mcp-authz, action-gate, agent-mtls, agent-cascade.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-apps

echo "==> Ensuring namespaces exist"
kubectl apply -f "$here/../shared/namespaces.yaml"

echo "==> Checking reused components are up (Keycloak from d1, Ollama from d3-ai)"
kubectl -n "$NS" get deploy/ollama >/dev/null 2>&1 || {
  echo "!! Ollama not found. Bring up lab-infra/ai first (./up.sh)." >&2; exit 1; }
kubectl -n oss500-identity get deploy/keycloak >/dev/null 2>&1 || \
  kubectl -n "$NS" get deploy/keycloak >/dev/null 2>&1 || {
  echo "!! Keycloak not found. Bring up lab-infra/identity first (Keycloak)." >&2; exit 1; }

echo "==> Loading OPA policies  [mcp-authz / action-gate]"
kubectl -n "$NS" create configmap agentic-opa-policy \
  --from-file="$here/opa/tool-authz.rego" \
  --from-file="$here/opa/action-class.rego" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Deploying the MCP server (tools: lookup [safe], submit_change [consequential])  [mcp-authn]"
kubectl -n "$NS" create configmap agentic-mcp-server \
  --from-file="$here/mcp-server/server.py" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Deploying the LangGraph agent scaffold  [mcp-authz / action-gate]"
kubectl -n "$NS" create configmap agentic-agent \
  --from-file="$here/agent/agent.py" \
  --from-file="$here/agent/requirements.txt" \
  --dry-run=client -o yaml | kubectl apply -f -

cat <<'EOF'
==> Supporting infra loaded into oss500-apps (OPA policy, MCP server, agent scaffold as configmaps).

    NEXT (per labs/d6-*.md — these are directions to complete, not a turnkey run):
      1. agent-deleg   : enable token exchange on the d1 realm  -> keycloak/token-exchange.md
      2. agent-workload: register the agent SVID with SPIRE      -> spire/registration.md
      3. run the MCP server + agent (venv or a Job) using the configmap'd sources
    Then work labs/d6-identity.md -> d6-tools-mcp -> d6-action-gating -> d6-multi-agent -> d6-validate.

    Honesty: the agent/MCP Python is reference scaffolding (LangGraph/MCP/RFC 8693 move fast).
    Label anything you did not personally run as *directions* in your notes.
EOF
