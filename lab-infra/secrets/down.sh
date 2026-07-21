#!/usr/bin/env bash
# Tear down Vault, the injector, and the Secrets Store CSI driver.
set -euo pipefail
NS=oss500-secrets

echo "==> Uninstalling Vault"
helm uninstall vault --namespace "$NS" || true

echo "==> Uninstalling Secrets Store CSI driver"
helm uninstall csi --namespace "$NS" || true

echo "==> Removing leftover SecretProviderClasses / demo SAs"
kubectl -n oss500-apps delete secretproviderclass --all --ignore-not-found || true
kubectl -n oss500-apps delete serviceaccount app --ignore-not-found || true

echo "==> Confirming nothing is left"
kubectl -n "$NS" get pods -l app.kubernetes.io/name=vault 2>/dev/null || true
echo "==> Done."
