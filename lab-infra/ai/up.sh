#!/usr/bin/env bash
# Bring up the AI security stack: Ollama (private) + Open WebUI + NeMo Guardrails + OPA gateway.
# Objectives: ai-access, ai-prompt, ai-guardrails, ai-rag, ai-observability, ai-governance.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-apps
MODEL="${OLLAMA_MODEL:-llama3.2:1b}"   # small model for the reference host; try qwen2.5:0.5b

echo "==> Ensuring namespaces exist"
kubectl apply -f "$here/../shared/namespaces.yaml"

if [[ ! -f "$here/open-webui.secret" ]]; then
  echo "!! Missing open-webui.secret — copy open-webui.secret.example and set values." >&2
  exit 1
fi

echo "==> Creating Open WebUI secret from open-webui.secret"
kubectl -n "$NS" create secret generic open-webui \
  --from-env-file="$here/open-webui.secret" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Deploying Ollama (ClusterIP-only, NetworkPolicy-locked)  [ai-access]"
kubectl apply -f "$here/ollama/deployment.yaml"
kubectl -n "$NS" rollout status deploy/ollama --timeout=5m

echo "==> Pulling model $MODEL into Ollama (first run downloads ~1.3 GB)"
kubectl -n "$NS" exec deploy/ollama -- ollama pull "$MODEL"

echo "==> Deploying NeMo Guardrails config  [ai-prompt / ai-guardrails]"
kubectl -n "$NS" create configmap nemo-guardrails \
  --from-file="$here/guardrails/config.yml" \
  --from-file="$here/guardrails/prompts.yml" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Deploying OPA gateway policy  [ai-access / ai-governance]"
kubectl -n "$NS" create configmap ai-gateway-policy \
  --from-file="$here/opa/gateway-policy.rego" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Deploying OpenTelemetry collector  [ai-observability]"
kubectl apply -f "$here/otel/collector.yaml"

echo "==> Deploying Open WebUI (chat + RAG front end)  [ai-rag]"
kubectl apply -f "$here/open-webui/deployment.yaml"
kubectl -n "$NS" rollout status deploy/open-webui --timeout=5m

echo "==> Done. Open WebUI: http://ai.oss500.local  (add to /etc/hosts -> 127.0.0.1)"
echo "    Ollama is NOT exposed (ai-access): kubectl -n $NS get svc ollama -> ClusterIP"
echo "    Guardrails/gateway sit in the request path; do labs/d3-ai-security.md."
