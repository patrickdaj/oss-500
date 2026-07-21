#!/usr/bin/env bash
# Tear down the network stack (policies, ingress+WAF, demo app). Also removes the mesh.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Removing NetworkPolicies"
kubectl -n oss500-apps delete -f "$here/policies/" --ignore-not-found || true

echo "==> Removing the demo app + client"
kubectl delete -f "$here/demo-app.yaml" --ignore-not-found || true

echo "==> Uninstalling ingress-nginx (WAF)"
helm uninstall ingress-nginx --namespace ingress-nginx || true

echo "==> Tearing down the mesh if present"
"$here/down-mesh.sh" || true

echo "==> Done.  (Re-run shared/up.sh if you want the plain kind ingress back.)"
