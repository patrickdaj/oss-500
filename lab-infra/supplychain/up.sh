#!/usr/bin/env bash
# Bring up the supply-chain stack: Harbor private registry with built-in Trivy.
# Objectives: sc-registry (registry+signing), sc-scan (built-in scanner).
# Trivy/Grype/Syft/cosign are CLIs — install separately (brew install trivy grype syft cosign).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-apps

echo "==> Ensuring namespaces exist"
kubectl apply -f "$here/../shared/namespaces.yaml"

if [[ ! -f "$here/harbor-admin.secret" ]]; then
  echo "!! Missing harbor-admin.secret — copy harbor-admin.secret.example and set a password." >&2
  exit 1
fi
ADMIN_PW="$(grep -E '^admin_password=' "$here/harbor-admin.secret" | cut -d= -f2-)"

echo "==> Adding Harbor Helm repo"
helm repo add harbor https://helm.goharbor.io
helm repo update

echo "==> Installing Harbor  [sc-registry / sc-scan]"
helm upgrade --install harbor harbor/harbor \
  --namespace "$NS" \
  -f "$here/harbor/values.yaml" \
  --set "harborAdminPassword=${ADMIN_PW}" \
  --wait --timeout 10m

echo "==> Harbor up at https://harbor.oss500.local  (add to /etc/hosts -> 127.0.0.1)"
echo "    Login: admin / <from harbor-admin.secret>"
echo "    Built-in Trivy scans images on push; set a per-project severity gate in the UI."
