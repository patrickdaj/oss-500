#!/usr/bin/env bash
# Tear down the Agentic Zero Trust stack. Leaves reused components (Keycloak/Ollama) alone.
set -euo pipefail
NS=oss500-apps

echo "==> Removing agent + MCP server + OPA policy configmaps"
kubectl -n "$NS" delete configmap agentic-agent agentic-mcp-server agentic-opa-policy --ignore-not-found
kubectl -n "$NS" delete deploy,svc,job -l app.kubernetes.io/part-of=agentic --ignore-not-found

echo "==> Done. Reused components (Keycloak from lab-infra/identity, Ollama from lab-infra/ai) left running."
echo "    Revert the token-exchange client + SPIRE agent entries per keycloak/token-exchange.md and spire/registration.md if you added them."
