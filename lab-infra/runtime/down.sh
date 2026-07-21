#!/usr/bin/env bash
# Tear down runtime security. Leaves no orphaned resources.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-security

echo "==> Removing any TracingPolicy from the enforcement lab"
kubectl delete -f "$here/tetragon/block-sensitive-read.yaml" --ignore-not-found

echo "==> Uninstalling Helm releases"
helm uninstall tetragon    --namespace "$NS" --ignore-not-found || true
helm uninstall falco-talon --namespace "$NS" --ignore-not-found || true
helm uninstall falco       --namespace "$NS" --ignore-not-found || true

echo "==> Done. The oss500-security namespace is shared (Kyverno/Gatekeeper live there too) — not deleted."
echo "    Confirm clean:  kubectl -n $NS get pods -l app.kubernetes.io/part-of=oss500"
