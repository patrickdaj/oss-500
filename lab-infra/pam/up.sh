#!/usr/bin/env bash
# lab-infra/pam — Teleport self-hosted cluster for the d1 privileged-access lab.
# Objectives: pam-jit (short-lived certs), pam-session (proxy-sync recording), pam-approval (access requests).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ns=oss500-identity

echo "==> Adding the Teleport Helm repo"
helm repo add teleport https://charts.releases.teleport.dev >/dev/null 2>&1 || true
helm repo update teleport

echo "==> Installing Teleport into $ns (security-relevant settings are commented in values.yaml)"
helm upgrade --install teleport teleport/teleport-cluster \
  -n "$ns" \
  -f "$here/values.yaml"

echo "==> Waiting for Teleport to become ready"
kubectl -n "$ns" rollout status deploy/teleport --timeout=300s

cat <<EOF

==> Teleport is up. Bootstrap roles and your first admin:

  # Create the lab roles (pam-jit / pam-approval):
  kubectl -n $ns exec -i deploy/teleport -- tctl create -f /dev/stdin < $here/roles.yaml

  # Create a user with an editor + requester role (prints a one-time signup URL):
  kubectl -n $ns exec deploy/teleport -- \\
    tctl users add alice --roles=editor,requester,db-oncall --logins=readonly

  # Port-forward the proxy and log in from your host:
  kubectl -n $ns port-forward deploy/teleport 3080:3080 &
  tsh login --insecure --proxy=localhost:3080 --user=alice

Verify:
  tsh status        # a short-lived cert (valid ~1h under db-oncall) — pam-jit
  kubectl -n $ns exec deploy/teleport -- tctl get roles   # db-oncall shows max_session_ttl: 1h
EOF
