# vault-access: least-privilege Vault policy for the demo "app" workload.
# Bound to the oss500-apps/app ServiceAccount by the kubernetes auth role.
# Policies are default-deny: a token may do ONLY what a path capability grants.

# Read a specific kv-v2 secret (note the /data/ segment for kv-v2 reads).
path "secret/data/app/*" {
  capabilities = ["read"]
}

# List metadata under the app prefix (no value access).
path "secret/metadata/app/*" {
  capabilities = ["list", "read"]
}

# vault-dynamic: pull short-lived database credentials for the "app" role.
path "database/creds/app" {
  capabilities = ["read"]
}

# key-transit: encrypt/decrypt with the shared data key (key never leaves Vault).
path "transit/encrypt/app-data" {
  capabilities = ["update"]
}
path "transit/decrypt/app-data" {
  capabilities = ["update"]
}

# Allow a token to look up and renew its own lease, nothing more.
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "sys/leases/renew" {
  capabilities = ["update"]
}
