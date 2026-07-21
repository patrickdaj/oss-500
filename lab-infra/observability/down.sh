#!/usr/bin/env bash
# Tear down the OSS-500 observability stack. Leaves the namespace + PSA labels
# (owned by shared/) in place; removes every Helm release and applied manifest.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ns=oss500-monitoring

echo "==> Removing manifests"
kubectl delete -f "$here/otel-collector.yaml" --ignore-not-found
kubectl delete -f "$here/alert-rules.yaml" --ignore-not-found
kubectl delete -f "$here/datasources.yaml" --ignore-not-found
kubectl delete secret alertmanager-oss500-kube-prometheus-stack-alertmanager -n "$ns" --ignore-not-found

echo "==> Uninstalling Helm releases"
helm uninstall oss500-tempo -n "$ns" 2>/dev/null || true
helm uninstall oss500-loki -n "$ns" 2>/dev/null || true
helm uninstall oss500-kube-prometheus-stack -n "$ns" 2>/dev/null || true

echo "==> Removing grafana-admin secret and any leftover PVCs"
kubectl delete secret grafana-admin -n "$ns" --ignore-not-found
kubectl delete pvc -n "$ns" -l app.kubernetes.io/part-of=oss500 --ignore-not-found

echo "==> Done. Confirm empty: kubectl get all -n $ns"
