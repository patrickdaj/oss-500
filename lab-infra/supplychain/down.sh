#!/usr/bin/env bash
# Tear down Harbor and its PVCs. Removes the Kyverno signature policy if applied.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-apps

echo "==> Removing admission policy (sc-admission), if present"
kubectl delete -f "$here/kyverno/require-signed-images.yaml" --ignore-not-found

echo "==> Uninstalling Harbor"
helm uninstall harbor --namespace "$NS" --ignore-not-found || true

echo "==> Deleting leftover Harbor PVCs (registry/db/redis storage)"
kubectl -n "$NS" delete pvc -l app.kubernetes.io/instance=harbor --ignore-not-found

echo "==> Done. Confirm clean:  kubectl -n $NS get all,pvc -l app.kubernetes.io/part-of=oss500"
