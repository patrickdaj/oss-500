#!/usr/bin/env bash
# Tear down the AI stack. Pass --purge to also delete the pulled-model PVC.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-apps

echo "==> Deleting Open WebUI, guardrails, gateway, OTel, Ollama"
kubectl delete -f "$here/open-webui/deployment.yaml" --ignore-not-found
kubectl delete -f "$here/otel/collector.yaml" --ignore-not-found
kubectl delete -f "$here/ollama/deployment.yaml" --ignore-not-found
kubectl -n "$NS" delete configmap nemo-guardrails ai-gateway-policy --ignore-not-found
kubectl -n "$NS" delete secret open-webui --ignore-not-found

if [[ "${1:-}" == "--purge" ]]; then
  echo "==> --purge: deleting model + Open WebUI PVCs"
  kubectl -n "$NS" delete pvc ollama-models open-webui-data --ignore-not-found
else
  echo "==> Keeping model PVC (ollama-models) so the next run skips the download. Use --purge to remove."
fi

echo "==> Done. Confirm clean:  kubectl -n $NS get all -l app.kubernetes.io/part-of=oss500"
