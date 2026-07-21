#!/usr/bin/env bash
# Bring up runtime security: Falco (+Falcosidekick +UI +Talon) and Tetragon.
# Objectives: rt-falco, rt-tetragon, rt-response.
# All into oss500-security (privileged by design — eBPF + host access).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-security

echo "==> Ensuring namespaces exist (privileged oss500-security)"
kubectl apply -f "$here/../shared/namespaces.yaml"

echo "==> Adding Helm repos"
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo add cilium https://helm.cilium.io/
helm repo update

# Optional Slack webhook for Falcosidekick (rt-response). Silently skipped if absent.
SLACK_ARGS=()
if [[ -f "$here/falcosidekick-slack.secret" ]]; then
  WEBHOOK="$(grep -E '^webhook=' "$here/falcosidekick-slack.secret" | cut -d= -f2-)"
  SLACK_ARGS=(--set "falcosidekick.config.slack.webhookurl=${WEBHOOK}")
  echo "==> Slack output enabled from falcosidekick-slack.secret"
fi

echo "==> Installing Falco (modern eBPF) + Falcosidekick + UI  [rt-falco / rt-response]"
helm upgrade --install falco falcosecurity/falco \
  --namespace "$NS" \
  -f "$here/falco/values.yaml" \
  "${SLACK_ARGS[@]}" \
  --wait --timeout 5m

echo "==> Installing Falco Talon response engine  [rt-response]"
helm upgrade --install falco-talon falcosecurity/falco-talon \
  --namespace "$NS" \
  --set-file config.rules="$here/talon/rules.yaml" \
  --wait --timeout 5m || echo "   (talon optional — continue if chart unavailable)"

echo "==> Installing Tetragon (eBPF observe + enforce)  [rt-tetragon]"
helm upgrade --install tetragon cilium/tetragon \
  --namespace "$NS" \
  -f "$here/tetragon/values.yaml" \
  --wait --timeout 5m

echo "==> Done. Watch alerts:  kubectl -n $NS logs -f ds/falco"
echo "    Tetragon events:     kubectl -n $NS exec ds/tetragon -c tetragon -- tetra getevents -o compact"
echo "    Apply enforcement:   kubectl apply -f $here/tetragon/block-sensitive-read.yaml"
