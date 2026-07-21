#!/usr/bin/env bash
# Tear down cert-manager, its issuers, and demo certificates.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-secrets

echo "==> Deleting demo certificates and issuers"
kubectl -n oss500-apps delete -f "$here/example-certificate.yaml" --ignore-not-found || true
kubectl delete -f "$here/clusterissuer.yaml" --ignore-not-found || true
kubectl -n "$NS" delete secret oss500-ca --ignore-not-found || true
kubectl -n oss500-apps delete secret demo-tls --ignore-not-found || true

echo "==> Uninstalling cert-manager (this removes the CRDs — crds.keep=false)"
helm uninstall cert-manager --namespace "$NS" || true

echo "==> Done."
