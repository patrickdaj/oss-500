# governance — Kyverno + OPA Gatekeeper + Kubescape

Admission-time policy engines and a compliance scanner for the Domain 1 governance lab ([guide](../../labs/d1-governance-policy.md)). Kyverno and Gatekeeper enforce (and remediate) organizational policy at admission — the open-source Azure Policy / Azure Policy for AKS. Kubescape scores the cluster against hardening frameworks — the secure-score / regulatory-compliance analogue.

**Objectives:** `gov-kyverno`, `gov-gatekeeper`, `gov-compliance`, `gov-iac` (touchpoint: `pod-admission`)
**Footprint:** ~1.0–1.5 GB · up ~3–5 min (Helm pulls + webhook readiness).

Kyverno and Gatekeeper install into `oss500-security`, which enforces the **privileged** Pod Security Standard by design (see [`shared/namespaces.yaml`](../shared/namespaces.yaml)) — admission controllers legitimately need the room. Kubescape is a CLI (nothing long-running to deploy).

```bash
# From this directory:
./up.sh                      # helm installs Kyverno + Gatekeeper, applies the policies

# Kubescape CLI (compliance scoring — gov-compliance):
curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash
#   optional continuous in-cluster scanning instead of the CLI:
#   helm repo add kubescape https://kubescape.github.io/helm-charts/ && \
#   helm upgrade --install kubescape kubescape/kubescape-operator -n oss500-security \
#     --set clusterName=$(kubectl config current-context)
```

**Verify** — prove the controls deny and the estate is scored (not just that the tools installed):
```bash
# gov-kyverno — a privileged pod is REJECTED by the Kyverno admission webhook:
kubectl -n oss500-apps run bad --image=nginx --privileged --dry-run=server
#   -> Error ... policy disallow-privileged/no-privileged-containers fail: Privileged containers are not allowed

# gov-gatekeeper — a namespace missing the required owner label is REJECTED:
kubectl create ns no-owner-test --dry-run=server
#   -> Error ... [ns-must-have-owner] missing required label(s): {"owner"}
#   Flip spec.enforcementAction to "dryrun" in gatekeeper-constraints.yaml and it is
#   ALLOWED but recorded — the Azure Policy Audit behaviour.

# gov-compliance — a severity-weighted compliance score against a framework:
kubescape scan framework nsa --format pretty-printer
kubescape scan framework cis --compliance-threshold 80   # non-zero exit below 80% (CI gate — gov-iac)

# gov-iac — review controls before applying, and scan the manifests shift-left:
helm template gatekeeper gatekeeper/gatekeeper | less
kubescape scan .                                          # scan this dir's YAML pre-deploy
```

**Teardown:** `./down.sh` (removes policies, uninstalls both releases, cleans Gatekeeper CRDs; namespaces stay). Confirm: `kubectl get all -A -l app.kubernetes.io/part-of=oss500 | grep -E 'kyverno|gatekeeper' || echo clean`.
