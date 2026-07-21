#!/usr/bin/env bash
# net-mesh teardown: remove the mesh policies, disable injection, uninstall Istio.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-apps

echo "==> Removing mesh policies"
kubectl -n "$NS" delete -f "$here/mesh/" --ignore-not-found || true

echo "==> Disabling sidecar injection in $NS"
kubectl label namespace "$NS" istio-injection- --overwrite || true

if command -v istioctl >/dev/null 2>&1; then
  echo "==> Uninstalling Istio"
  istioctl uninstall --purge -y || true
fi
kubectl delete namespace istio-system --ignore-not-found || true
echo "==> Done."
