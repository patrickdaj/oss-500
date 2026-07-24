#!/usr/bin/env bash
# Bring up the OSS-500 identity component: Keycloak on the official upstream image
# (quay.io/keycloak/keycloak, start-dev/H2) into oss500-identity. Wraps kubectl only.
# (Was the Bitnami Helm chart + PostgreSQL until Bitnami removed the images from
# Docker Hub's free namespace in 2025 — see keycloak.yaml.)
# Objectives: kc-deploy, kc-mfa, kc-ca, kc-clients, kc-federation, kc-consent.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/../.." && pwd)"
ns="oss500-identity"

# kc-deploy: the admin password comes from the gitignored admin-password.env.
if [[ ! -f "$here/admin-password.env" ]]; then
  echo "ERROR: $here/admin-password.env not found." >&2
  echo "       cp admin-password.env.example admin-password.env  and set a real password." >&2
  exit 1
fi
# shellcheck disable=SC1091
source "$here/admin-password.env"
: "${KEYCLOAK_ADMIN_PASSWORD:?set KEYCLOAK_ADMIN_PASSWORD in admin-password.env}"

echo "==> Ensuring OSS-500 namespaces + Pod Security labels exist"
kubectl apply -f "$repo_root/lab-infra/shared/namespaces.yaml"

echo "==> Creating/updating the keycloak-admin secret from admin-password.env (never committed)"
kubectl create secret generic keycloak-admin \
  --namespace "$ns" \
  --from-literal=admin-password="$KEYCLOAK_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
# Label the secret for teardown discovery.
kubectl label secret keycloak-admin -n "$ns" app.kubernetes.io/part-of=oss500 --overwrite >/dev/null

echo "==> Deploying Keycloak (official quay.io/keycloak image) into $ns"
kubectl apply -f "$here/keycloak.yaml"

echo "==> Waiting for Keycloak to be ready (start-dev boots in ~30-60s)"
kubectl rollout status deployment/keycloak -n "$ns" --timeout=300s

cat <<EOF

==> Keycloak is up in namespace $ns.
    Add to /etc/hosts:   127.0.0.1  keycloak.oss500.local
    Admin console:       http://keycloak.oss500.local:8080/admin  (user: admin)
    Or port-forward:     kubectl -n $ns port-forward svc/keycloak 8080:80

    Verify (kcadm inside the pod):
      kubectl -n $ns exec deploy/keycloak -- \\
        /opt/keycloak/bin/kcadm.sh config credentials \\
        --server http://localhost:8080 --realm master --user admin --password '<pw>'
      kubectl -n $ns exec deploy/keycloak -- /opt/keycloak/bin/kcadm.sh get realms

    Now run the lab: labs/d1-keycloak-sso-mfa.md
EOF
