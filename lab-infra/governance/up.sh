#!/usr/bin/env bash
# Bring up the OSS-500 governance stack: Kyverno + OPA Gatekeeper, then apply the
# lab policies. Kubescape is a CLI scanner (see README) — nothing to deploy for it.
# Objectives: gov-kyverno, gov-gatekeeper (compliance/IaC done from the CLI).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/../.." && pwd)"

echo "==> Ensuring OSS-500 namespaces exist (oss500-security is privileged PSS by design)"
kubectl apply -f "$repo_root/lab-infra/shared/namespaces.yaml"

echo "==> Adding Helm repos"
helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts >/dev/null
helm repo update >/dev/null

echo "==> Installing Kyverno into oss500-security (gov-kyverno)"
helm upgrade --install kyverno kyverno/kyverno \
  -n oss500-security \
  --set admissionController.replicas=1 \
  --set backgroundController.replicas=1 \
  --set reportsController.replicas=1 \
  --set customLabels."app\.kubernetes\.io/part-of"=oss500 \
  --wait --timeout 5m

echo "==> Installing OPA Gatekeeper into oss500-security (gov-gatekeeper)"
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  -n oss500-security \
  --set replicas=1 \
  --set auditInterval=60 \
  --set emitAdmissionEvents=true \
  --set emitAuditEvents=true \
  --set enableMutation=true \
  --set podLabels."app\.kubernetes\.io/part-of"=oss500 \
  --wait --timeout 5m

echo "==> Waiting for admission controllers to be ready"
kubectl -n oss500-security rollout status deploy/kyverno-admission-controller --timeout=180s || true
kubectl -n oss500-security rollout status deploy/gatekeeper-controller-manager --timeout=180s || true

echo "==> Applying Gatekeeper ConstraintTemplate, then (after CRD registers) the Constraint"
kubectl apply -f "$here/gatekeeper-templates.yaml"
# The Constraint's CRD is generated from the template — wait for it to appear.
kubectl wait --for=condition=established --timeout=90s \
  crd/k8srequiredlabels.constraints.gatekeeper.sh
kubectl apply -f "$here/gatekeeper-constraints.yaml"

echo "==> Applying Kyverno policies (gov-kyverno)"
kubectl apply -f "$here/kyverno-policies.yaml"

cat <<'EOF'
==> Done. Verify the controls actually deny:
    # Kyverno should REJECT a privileged pod:
    kubectl -n oss500-apps run bad --image=nginx --privileged --dry-run=server
    # Gatekeeper should REJECT a namespace with no owner label:
    kubectl create ns no-owner-test --dry-run=server
    # Compliance score (install the kubescape CLI first — see README):
    kubescape scan framework nsa
Teardown:  ./down.sh
EOF
