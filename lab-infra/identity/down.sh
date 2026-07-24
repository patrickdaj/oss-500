#!/usr/bin/env bash
# Tear down the OSS-500 identity component: the Keycloak Deployment/Service and the
# admin secret. State is disposable (start-dev/embedded H2 — no PVCs).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ns="oss500-identity"

echo "==> Deleting Keycloak (Deployment + Service)"
kubectl delete -f "$here/keycloak.yaml" --ignore-not-found

echo "==> Deleting the keycloak-admin secret"
kubectl delete secret keycloak-admin -n "$ns" --ignore-not-found

echo "==> Remaining OSS-500 resources in $ns (should be empty):"
kubectl get all -n "$ns" -l app.kubernetes.io/part-of=oss500 || true
echo "==> Done. The oss500-identity namespace itself is left in place (shared)."
