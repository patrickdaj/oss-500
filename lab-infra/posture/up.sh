#!/usr/bin/env bash
# Prepare the posture toolchain (vuln-*): install the Kubescape + Trivy CLIs if
# missing, and apply the kube-bench Job. Requires the kind cluster + shared/up.sh.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ns=oss500-security

kubectl get ns "$ns" >/dev/null 2>&1 || { echo "Run ../shared/up.sh first (missing $ns)"; exit 1; }

if ! command -v kubescape >/dev/null 2>&1; then
  echo "==> Installing Kubescape CLI"
  curl -sSL https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash
fi

if ! command -v trivy >/dev/null 2>&1; then
  echo "==> Installing Trivy CLI"
  curl -sSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b "${HOME}/.local/bin"
  echo "    (ensure ${HOME}/.local/bin is on PATH)"
fi

echo "==> Applying kube-bench Job (CIS benchmark) in $ns"
kubectl apply -f "$here/kube-bench-job.yaml" -n "$ns"

cat <<EOF
==> Done.
  Deploy a scan target:  kubectl apply -f $here/insecure-demo.yaml -n $ns
  Posture scan:          kubescape scan
  CIS results:           kubectl logs -f job/kube-bench -n $ns
  Image CVEs:            trivy image --severity CRITICAL,HIGH nginx:1.21.0
EOF
