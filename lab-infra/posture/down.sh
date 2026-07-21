#!/usr/bin/env bash
# Tear down the posture lab: remove the Jobs and demo workloads. CLIs stay installed.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Removing demo workloads"
kubectl delete -f "$here/insecure-demo.yaml" -n oss500-security --ignore-not-found
kubectl delete -f "$here/secure-demo.yaml" -n oss500-apps --ignore-not-found

echo "==> Removing scan Jobs"
kubectl delete -f "$here/kube-bench-job.yaml" -n oss500-security --ignore-not-found
kubectl delete -f "$here/kubescape-job.yaml" -n oss500-security --ignore-not-found

echo "==> Done. Confirm:  kubectl get all -n oss500-security -l app.kubernetes.io/part-of=oss500"
