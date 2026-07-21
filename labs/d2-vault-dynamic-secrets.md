# Lab d2: Vault dynamic secrets, policies & audit

Issue a database credential that Postgres accepts, watch it expire on its lease, and prove every secret read is in the audit log — the Key Vault story with credentials that never outlive their use.

**Objectives covered**

| id | Objective |
|---|---|
| `vault-deploy` | Deploy a secrets manager and understand seal/unseal and storage backends |
| `vault-access` | Configure access with auth methods and policies |
| `vault-dynamic` | Issue dynamic, short-lived secrets with leases and revocation |
| `vault-rotation` | Configure secret rotation for static and dynamic credentials |
| `vault-audit` | Enable audit devices and monitor secret access |

**SC-500 correspondence**: Azure Key Vault (secrets store) · managed credentials / rotation (dynamic secrets + rotate-root) · Key Vault diagnostics / Defender for Key Vault (audit devices)

**Prerequisites**

- [`lab-infra/secrets`](../lab-infra/secrets/) up (`./up.sh`) — Vault in the `oss500-secrets` namespace, Raft storage, initialized/unsealed by the script (init keys written to a gitignored file).
- Notes read: [secrets-management.md](../domains/2-secrets-data-networking/secrets-management.md).
- A Postgres pod for the dynamic-secrets engine (the component's `up.sh` deploys one, or apply `lab-infra/secrets/postgres.yaml`).

**Estimated time**: 2–3 h · $0 (local)

## Steps

Open a shell to the Vault pod (or port-forward and use a local `vault` binary). All commands below assume `VAULT_ADDR` points at the Vault service and you are logged in with the root/init token from the gitignored `secrets/.vault-init.json`.

```bash
kubectl -n oss500-secrets exec -it statefulset/vault -- sh
export VAULT_ADDR=http://127.0.0.1:8200
vault login <root-token>          # from secrets/.vault-init.json
```

### Part A — Deploy, seal & storage backend (`vault-deploy`)

1. Confirm Vault is up and **unsealed**:
   ```bash
   vault status
   ```
   Read the output: `Seal Type shamir`, `Initialized true`, `Sealed false`, `Storage Type raft`. Vault boots **sealed** — its master key is split into Shamir key shares; a threshold of shares must be supplied (`vault operator unseal`) before Vault can decrypt anything. The `up.sh` did this for you; a restart re-seals it.
2. Inspect the storage backend. This lab uses **integrated storage (Raft)** — Vault's own replicated log, no external Consul. List the Raft peers:
   ```bash
   vault operator raft list-peers
   ```
   The seal wraps the encryption key that protects everything Raft persists on disk, so the storage backend is never plaintext at rest. (SC-500 analogue: you don't manage Key Vault's HSM/seal, but the *concept* — a root of trust unwrapping the data-protection key — is the same.)
3. (Optional, to feel seal/unseal) `vault operator seal`, run `vault status` (now `Sealed true`, all operations fail), then unseal with the shares:
   ```bash
   vault operator unseal <share-1>
   vault operator unseal <share-2>
   vault operator unseal <share-3>
   ```

### Part B — Auth methods & policies (`vault-access`)

4. Enable two auth methods — `userpass` for humans, `kubernetes` for workloads (used in the injector lab):
   ```bash
   vault auth enable userpass
   vault auth enable kubernetes
   ```
5. Write a **least-privilege HCL policy** that can only read one KV path — this is Vault's equivalent of a scoped Key Vault RBAC role:
   ```bash
   cat > app-policy.hcl <<'EOF'
   # app-ro: read-only on one application's KV-v2 path, nothing else.
   path "secret/data/app/*" {
     capabilities = ["read"]
   }
   # deny everything not explicitly granted (Vault is default-deny anyway)
   EOF
   vault policy write app-ro app-policy.hcl
   ```
6. Create a user bound to that policy and log in as them in a second shell:
   ```bash
   vault write auth/userpass/users/appdev password=devpass policies=app-ro
   VAULT_TOKEN=$(vault login -token-only -method=userpass username=appdev password=devpass)
   ```
7. Prove the scope with `token capabilities` — the exam-style "can this principal do X?" check:
   ```bash
   VAULT_TOKEN=$appdev_token vault token capabilities secret/data/app/config   # -> read
   VAULT_TOKEN=$appdev_token vault token capabilities secret/data/other        # -> deny
   ```
   Same identity, different path → allowed vs denied. That is Vault's authorization model: **auth method proves who you are, policy decides what you may touch.**

### Part C — Dynamic database secrets (`vault-dynamic`)

8. Enable the database secrets engine and point it at the Postgres pod:
   ```bash
   vault secrets enable database

   vault write database/config/appdb \
       plugin_name=postgresql-database-plugin \
       allowed_roles="app" \
       connection_url="postgresql://{{username}}:{{password}}@postgres.oss500-secrets:5432/appdb?sslmode=disable" \
       username="vaultadmin" password="vaultadminpw"
   ```
9. Define a **role** — the SQL Vault runs to mint a brand-new user on demand, with a short lease:
   ```bash
   vault write database/roles/app \
       db_name=appdb \
       creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
                            GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
       default_ttl="2m" max_ttl="10m"
   ```
10. Request a credential. Note there was **no such user a second ago** — Vault created it:
    ```bash
    vault read database/creds/app
    # Key                Value
    # lease_id           database/creds/app/AbCdEf...
    # lease_duration     2m
    # password           A1a-...
    # username           v-userpass-app-XyZ...
    ```
11. **Prove Postgres accepts it** (from a psql-capable pod):
    ```bash
    PGPASSWORD='<password>' psql -h postgres.oss500-secrets -U 'v-userpass-app-XyZ...' -d appdb -c 'SELECT 1;'   # -> 1 row
    ```
12. **Watch it expire.** Wait past the 2-minute `default_ttl` (or force it) and retry — Postgres now rejects the login because Vault dropped the role:
    ```bash
    vault lease revoke -prefix database/creds/app      # immediate revocation of every issued cred
    PGPASSWORD='<password>' psql -h postgres.oss500-secrets -U 'v-userpass-app-XyZ...' -d appdb -c 'SELECT 1;'
    # psql: FATAL: password authentication failed  (the role no longer exists)
    ```
    This is the payoff: **the credential is short-lived and revocable centrally** — the OSS equivalent of managed identities / auto-rotated credentials, and the reason a leaked dynamic cred is near-worthless minutes later.

### Part D — Rotation: root + static KV versions (`vault-rotation`)

13. **Rotate the root** database credential so *even you* no longer know the password Vault uses to manage the DB — from now on only Vault holds it:
    ```bash
    vault write -f database/rotate-root/appdb
    ```
    (After this, `vaultadminpw` is invalid; Vault stores the new password internally.)
14. For **static** secrets, use KV-v2 versioning as the rotation record. Each `put` is a new version; old versions stay retrievable and auditable:
    ```bash
    vault kv put secret/app/config api_key=key-v1
    vault kv put secret/app/config api_key=key-v2      # rotation event
    vault kv get -version=1 secret/app/config          # old value still readable
    vault kv metadata get secret/app/config            # shows version history + timestamps
    ```
15. (Optional) For a KV secret you want Vault to rotate *for* you, enable a **KV rotation** with a rotation schedule, or use the database engine's `rotation` on a static role (`vault write database/static-roles/...` with `rotation_period`). The pattern: Vault owns the credential and cycles it on a schedule; consumers always read "the current one."

### Part E — Audit devices (`vault-audit`)

16. Enable a **file audit device** — Vault refuses to process a request if it can't write the audit log (fail-closed), the OSS analogue of Key Vault `AuditEvent` diagnostics:
    ```bash
    vault audit enable file file_path=/vault/audit/audit.log
    ```
17. Read a secret to generate an event, then inspect the log:
    ```bash
    vault kv get secret/app/config
    tail -n 1 /vault/audit/audit.log | jq .
    ```
18. Note in the JSON: the request `path`, the `auth` block (which token/policy), the client IP, and that the **secret value is HMAC'd, not plaintext** — auditors see *that* the secret was accessed and *by whom*, without the log itself becoming a secret store. This is exactly what you'd forward to Loki/Wazuh (Phase 4) to alert on anomalous access — the Defender-for-Key-Vault analogue.

## Verification

- **Dynamic credential works then dies**: `vault read database/creds/app` yields a username/password that `psql` authenticates with, and the *same* credential fails to authenticate after its lease TTL expires or after `vault lease revoke -prefix`. Proves short-lived, centrally-revocable secrets.
- **Policy scoping**: `vault token capabilities` returns `read` for the granted path and `deny` for any other path under the `app-ro` token.
- **Audit trail**: `tail audit.log | jq` shows a structured entry for the `secret/app/config` read with the accessing token and an **HMAC** (not the plaintext) of the value.
- **Rotation**: `vault kv get -version=1` still returns the old value after a `put`; `rotate-root` invalidates the original DB admin password.

## Teardown

- `cd lab-infra/secrets && ./down.sh`

## What the exam asks

- Vault boots **sealed**; unsealing (Shamir key shares or auto-unseal) must precede any operation — the "Vault returns 503 / 'Vault is sealed'" scenario. Maps to how Key Vault/Managed HSM are protected by a root of trust you don't hold directly.
- **Dynamic vs static** secrets: dynamic credentials are generated per-request with a lease and are revocable/expiring — the preferred answer whenever the scenario says "credentials keep leaking" or "reduce standing access." Static secrets need explicit rotation.
- **Least privilege** in Vault = auth method (identity) + policy (path capabilities). A principal that can authenticate but has the wrong policy gets `permission denied` — distinguish an *authn* failure from an *authz* (policy) failure, just like `ForbiddenByRbac` vs a network deny in Key Vault.
- **Audit devices fail closed**: if no audit device can record a request, Vault blocks the request. "Enable diagnostics so who-accessed-what is logged" → audit device, forwarded to a SIEM.
- `rotate-root` means the operator deliberately gives up knowledge of the managing credential so only Vault holds it — a common "remove standing human access to the DB admin password" answer.
