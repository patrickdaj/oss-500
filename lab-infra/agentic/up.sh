#!/usr/bin/env bash
# Bring up the Agentic Zero Trust stack: SPIRE (workload identity) + MCP server
# + OPA (tool + action policy) + LangGraph agent.
# Reuses Keycloak (lab-infra/identity) and Ollama (lab-infra/ai) — does NOT redeploy them.
# SPIRE IS deployed here (Domain 1 covered SPIFFE/SPIRE only as a walkthrough).
# Objectives: agent-deleg, agent-workload, mcp-authn, mcp-authz, action-gate, agent-mtls, agent-cascade.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-apps

echo "==> Ensuring namespaces exist"
kubectl apply -f "$here/../shared/namespaces.yaml"

echo "==> Deploying SPIRE (server + agent + CSI + controller-manager)  [agent-workload]"
# Real SPIRE into oss500-identity so the agent's SVID is genuinely issued.
helm repo add spiffe https://spiffe.github.io/helm-charts-hardened/ >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install spire-crds spiffe/spire-crds \
  --namespace oss500-identity --create-namespace
helm upgrade --install spire spiffe/spire \
  --namespace oss500-identity \
  -f "$here/spire/values.yaml" --wait --timeout 5m
echo "==> Registering agent SVIDs via ClusterSPIFFEID  [agent-workload / agent-mtls]"
kubectl apply -f "$here/spire/clusterspiffeids.yaml"

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

    SPIRE is deployed (oss500-identity); agent-a/agent-b SVIDs auto-register via
    the ClusterSPIFFEID CRs once those pods run. NEXT (per labs/d6-*.md):
      1. agent-deleg   : enable token exchange on the d1 realm  -> keycloak/token-exchange.md
      2. agent-workload: confirm the SVID is issued              -> spire/registration.md
      3. run the MCP server + agent (venv or a Job) using the configmap'd sources
    Then work labs/d6-identity.md -> d6-tools-mcp -> d6-action-gating -> d6-multi-agent -> d6-validate.

    Honesty: the agent/MCP Python is reference scaffolding (LangGraph/MCP/RFC 8693 move fast).
    Label anything you did not personally run as *directions* in your notes.
EOF
