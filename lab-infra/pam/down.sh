#!/usr/bin/env bash
# Full teardown of the Teleport PAM component — no orphaned PVCs, secrets, or recordings.
set -euo pipefail
ns=oss500-identity

echo "==> Uninstalling Teleport"
helm uninstall teleport -n "$ns" || true

echo "==> Removing PVCs and generated secrets (session recordings + cluster state)"
kubectl -n "$ns" delete pvc  -l app.kubernetes.io/instance=teleport --ignore-not-found
kubectl -n "$ns" delete secret -l app.kubernetes.io/instance=teleport --ignore-not-found

echo "==> Done. Confirm nothing is left:"
echo "    kubectl get all -n $ns -l app.kubernetes.io/part-of=oss500"
