#!/usr/bin/env bash
# Tear down Vault (Raft), the injector, the Secrets Store CSI driver, and the
# Postgres dynamic-secrets backend. Leaves no orphaned resources.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-secrets

echo "==> Removing the Postgres backend"
kubectl delete -f "$here/postgres.yaml" --ignore-not-found || true

echo "==> Uninstalling Vault"
helm uninstall vault --namespace "$NS" || true

echo "==> Uninstalling Secrets Store CSI driver"
helm uninstall csi --namespace "$NS" || true

echo "==> Removing the Raft data PVC and the local init file (clean reset)"
kubectl -n "$NS" delete pvc -l app.kubernetes.io/name=vault --ignore-not-found || true
rm -f "$here/.vault-init.json"

echo "==> Removing leftover SecretProviderClasses / demo SAs"
kubectl -n oss500-apps delete secretproviderclass --all --ignore-not-found || true
kubectl -n oss500-apps delete serviceaccount app --ignore-not-found || true

echo "==> Confirming nothing is left"
kubectl -n "$NS" get pods -l app.kubernetes.io/name=vault 2>/dev/null || true
kubectl -n "$NS" get pods -l app=postgres 2>/dev/null || true
echo "==> Done."
