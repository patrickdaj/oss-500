#!/usr/bin/env bash
# Post-install Vault configuration for the OSS-500 secrets labs.
# Runs `vault` inside the vault-0 pod (dev root token "root").
# Each block maps to a d2-secrets / d2-keys-certs objective.
set -euo pipefail
NS=oss500-secrets
POD=vault-0

vex() { kubectl -n "$NS" exec -i "$POD" -- sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root $*"; }

echo "==> [vault-audit] Enable a file audit device (HMACs sensitive values)"
# vault-audit: every request/response is logged as JSON; secret values are
# HMAC-SHA256'd, not written in clear. Disable-and-re-enable is idempotent-ish;
# ignore 'already enabled'.
vex 'vault audit enable file file_path=/vault/audit/audit.log' || true

echo "==> [vault-access] Enable the Kubernetes auth method"
# vault-access: pods authenticate with their ServiceAccount JWT; Vault verifies
# it against the cluster's token reviewer and issues a scoped Vault token.
vex 'vault auth enable kubernetes' || true
vex 'vault write auth/kubernetes/config \
      kubernetes_host=https://$KUBERNETES_PORT_443_TCP_ADDR:443' || true

echo "==> [vault-access] Load the app policy and a kv-v2 store"
vex 'vault secrets enable -path=secret -version=2 kv' || true
# app-policy.hcl is applied from the host copy (kept in policies/).
kubectl -n "$NS" cp "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/policies/app-policy.hcl" \
  "$POD:/tmp/app-policy.hcl"
vex 'vault policy write app /tmp/app-policy.hcl'
# vault-access: bind the policy to a ServiceAccount via a kubernetes auth role.
vex 'vault write auth/kubernetes/role/app \
      bound_service_account_names=app \
      bound_service_account_namespaces=oss500-apps \
      policies=app ttl=1h' || true

echo "==> [key-transit] Enable the transit engine (encryption-as-a-service)"
# key-transit: keys never leave Vault; clients send plaintext and get ciphertext.
vex 'vault secrets enable transit' || true
vex 'vault write -f transit/keys/app-data' || true

echo "==> [vault-dynamic] Enable the database secrets engine (skeleton)"
# vault-dynamic: Vault mints short-lived Postgres roles on demand and revokes
# them when the lease expires. The lab deploys the Postgres pod and completes
# the connection/role config (see labs/d2-vault-dynamic-secrets.md).
vex 'vault secrets enable database' || true
cat <<'EOF'

==> [vault-dynamic] Finish in the lab once Postgres is running, e.g.:

    vault write database/config/lab-postgres \
      plugin_name=postgresql-database-plugin \
      allowed_roles="app" \
      connection_url="postgresql://{{username}}:{{password}}@postgres.oss500-apps:5432/postgres?sslmode=disable" \
      username="vault" password="vault-root-pw"

    vault write database/roles/app \
      db_name=lab-postgres \
      creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
                           GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
      default_ttl="1m" max_ttl="5m"        # vault-dynamic: short leases

    vault read database/creds/app          # dynamic, expiring credential
    # vault-rotation: rotate the root connection password so even the operator
    # who bootstrapped it can no longer use it:
    vault write -f database/rotate-root/lab-postgres
EOF
