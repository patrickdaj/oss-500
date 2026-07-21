#!/usr/bin/env bash
# Tear down the OSS-500 governance stack. Policies first (so nothing blocks the
# uninstall), then the Helm releases. Leaves the namespaces (shared) in place.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Removing lab policies / constraints / templates"
kubectl delete -f "$here/kyverno-policies.yaml" --ignore-not-found
kubectl delete -f "$here/gatekeeper-constraints.yaml" --ignore-not-found
kubectl delete -f "$here/gatekeeper-templates.yaml" --ignore-not-found

echo "==> Uninstalling Gatekeeper"
helm uninstall gatekeeper -n oss500-security --ignore-not-found || true

echo "==> Uninstalling Kyverno"
helm uninstall kyverno -n oss500-security --ignore-not-found || true

echo "==> Cleaning up any leftover Gatekeeper CRDs"
kubectl get crd -o name | grep -E 'gatekeeper\.sh' | xargs -r kubectl delete --ignore-not-found

echo "==> Done. Confirm nothing lingers:"
echo "    kubectl get all -A -l app.kubernetes.io/part-of=oss500 | grep -E 'kyverno|gatekeeper' || echo clean"
