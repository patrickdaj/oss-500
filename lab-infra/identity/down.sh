#!/usr/bin/env bash
# Tear down the OSS-500 identity component. Removes the Keycloak release, the
# admin secret, and the PostgreSQL PVCs (state is disposable in the lab).
set -euo pipefail
ns="oss500-identity"

echo "==> helm uninstall keycloak"
helm uninstall keycloak -n "$ns" 2>/dev/null || echo "    (release already gone)"

echo "==> Deleting the keycloak-admin secret"
kubectl delete secret keycloak-admin -n "$ns" --ignore-not-found

echo "==> Deleting leftover PVCs (Keycloak + PostgreSQL data)"
kubectl delete pvc -n "$ns" -l app.kubernetes.io/instance=keycloak --ignore-not-found

echo "==> Remaining OSS-500 resources in $ns (should be empty):"
kubectl get all -n "$ns" -l app.kubernetes.io/part-of=oss500 || true
echo "==> Done. The oss500-identity namespace itself is left in place (shared)."
