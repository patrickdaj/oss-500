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
- A Postgres backend for the dynamic-secrets engine: the component's `up.sh` deploys it (Service `postgres.oss500-secrets`, db `appdb`, admin `vaultadmin`) plus a `psql-client` pod. Run the Part C `psql` checks from that pod, e.g. `kubectl -n oss500-secrets exec deploy/psql-client -- env PGPASSWORD='<pw>' psql -h postgres.oss500-secrets -U '<user>' -d appdb -c 'SELECT 1;'`.

**Estimated time**: 2–3 h · $0 (local)

Open a shell to the Vault pod (or port-forward and use a local `vault` binary). All commands below assume `VAULT_ADDR` points at the Vault service and you are logged in with the root/init token from the gitignored `secrets/.vault-init.json`.

```bash
kubectl -n oss500-secrets exec -it statefulset/vault -- sh
export VAULT_ADDR=http://127.0.0.1:8200
vault login <root-token>          # from secrets/.vault-init.json
```

## Challenge

Build out Vault's full trust story on top of the running server: an auth method plus a least-privilege policy that provably allows one path and denies another for the same identity; a dynamic database secrets engine that mints a brand-new Postgres role on demand, short-lived enough that it dies on its own and can be revoked centrally; a root-credential rotation so that even you no longer know the password Vault uses to manage the database; and an audit device that proves every secret read is logged — without the log itself ever holding the plaintext.

Reach these observables (see Verification for the exact checks):

- `vault read database/creds/app` returns a username/password that `psql` authenticates with — and the *same* credential fails to authenticate once its lease TTL expires or after you force-revoke it.
- `vault token capabilities` returns `read` for the one path your policy grants, and `deny` for any other path, using the same token both times.
- `tail audit.log | jq` shows a structured entry for a `secret/app/config` read, with the accessing token identified and the value **HMAC'd**, never plaintext.
- After a KV `put`, `vault kv get -version=1` still returns the prior value; after `rotate-root`, the original DB admin password no longer works.

## Build it (guided)

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
3. **Your turn (optional), to feel seal/unseal**: run `vault operator seal`, then `vault status` (it should now read `Sealed true`, and every other operation should fail). Bring it back with the Shamir shares you were given at init:
   ```bash
   vault operator unseal <share-1>
   vault operator unseal <share-2>
   vault operator unseal <share-3>
   ```
   Confirm `vault status` reads `Sealed false` again before moving on.

### Part B — Auth methods & policies (`vault-access`)

4. **Your turn.** Enable two auth methods — `userpass` for humans, `kubernetes` for workloads (used in the injector lab). One `vault auth enable <method>` call per method; check `vault auth list` afterward to confirm both are mounted.
5. **Design and write a least-privilege HCL policy** — this is Vault's equivalent of a scoped Key Vault RBAC role. It must let its holder *read* one application's KV-v2 path and nothing else (Vault is default-deny anyway, so you only need to write the one `path` block you want to allow). Scaffold to fill in:
   ```hcl
   # app-ro: read-only on one application's KV-v2 path, nothing else.
   path "secret/data/???" {
     capabilities = [???]
   }
   ```
   Name the file, then load it:
   ```bash
   vault policy write app-ro <your-file>.hcl
   ```
6. **Your turn.** Create a user bound to that policy, then log in as them from a second shell to get a scoped token:
   - `vault write auth/userpass/users/<name> password=<pw> policies=app-ro`
   - Capture a token-only login for that user (hint: `vault login -token-only -method=userpass username=... password=...`) into a shell variable, e.g. `appdev_token`.
7. **Prove the scope** with `token capabilities` — the exam-style "can this principal do X?" check. Using the `appdev` token, run `vault token capabilities` against the path your policy grants, then against a path it doesn't:
   ```bash
   VAULT_TOKEN=$appdev_token vault token capabilities secret/data/app/config   # expect: read
   VAULT_TOKEN=$appdev_token vault token capabilities secret/data/other        # expect: deny
   ```
   Same identity, different path → allowed vs denied. That is Vault's authorization model: **auth method proves who you are, policy decides what you may touch.**

### Part C — Dynamic database secrets (`vault-dynamic`)

8. **Your turn.** Enable the database secrets engine, then configure a connection to the Postgres pod. You need: the plugin name for Postgres, the role(s) allowed to use this connection, a `{{username}}`/`{{password}}`-templated connection URL pointing at the in-cluster Postgres service, and a real admin username/password for that Postgres instance.
   ```bash
   vault secrets enable database

   vault write database/config/appdb \
       plugin_name=???-database-plugin \
       allowed_roles="???" \
       connection_url="postgresql://{{username}}:{{password}}@???:5432/appdb?sslmode=disable" \
       username="???" password="???"
   ```
9. **Design the role** — the SQL Vault runs to mint a brand-new user on demand, with a short lease. You need `creation_statements` that `CREATE ROLE` with a login password and an expiration, then `GRANT SELECT` on the schema the app reads, plus a `default_ttl`/`max_ttl` short enough to *watch* expire (minutes, not hours):
   ```bash
   vault write database/roles/app \
       db_name=appdb \
       creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
                            GRANT ??? ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
       default_ttl="???" max_ttl="???"
   ```
10. Request a credential. Note there was **no such user a second ago** — Vault created it:
    ```bash
    vault read database/creds/app
    ```
    Note the `lease_id`, `lease_duration`, `username`, and `password` fields in the output.
11. **Prove Postgres accepts it** (from a psql-capable pod), using the username/password you just got back:
    ```bash
    PGPASSWORD='<password>' psql -h postgres.oss500-secrets -U '<username>' -d appdb -c 'SELECT 1;'   # expect: 1 row
    ```
12. **Watch it expire.** Wait past the `default_ttl` you configured (or force it) and retry — Postgres should now reject the login because Vault dropped the role. To force it, revoke every credential issued under this role in one call, then repeat the same `psql` command from step 11 and note the failure:
    ```bash
    vault lease revoke -prefix database/creds/app
    ```
    This is the payoff: **the credential is short-lived and revocable centrally** — the OSS equivalent of managed identities / auto-rotated credentials, and the reason a leaked dynamic cred is near-worthless minutes later.

### Part D — Rotation: root + static KV versions (`vault-rotation`)

13. **Your turn.** Rotate the root database credential so *even you* no longer know the password Vault uses to manage the DB — from now on only Vault holds it. Look for a `database/rotate-root/<connection-name>` write. Afterward, confirm the original admin password you configured in step 8 no longer works against Postgres directly.
14. For **static** secrets, use KV-v2 versioning as the rotation record. Put a value, then put a new value at the same path (a rotation event), then prove the old version is still retrievable and the history is auditable:
    - `vault kv put secret/app/config <key>=<value-1>`
    - `vault kv put secret/app/config <key>=<value-2>` — this is the rotation event
    - `vault kv get -version=1 secret/app/config` — old value should still read back
    - `vault kv metadata get secret/app/config` — should show version history + timestamps
15. (Optional) For a KV secret you want Vault to rotate *for* you, enable a **KV rotation** with a rotation schedule, or use the database engine's `rotation` on a static role (`vault write database/static-roles/...` with `rotation_period`). The pattern: Vault owns the credential and cycles it on a schedule; consumers always read "the current one."

### Part E — Audit devices (`vault-audit`)

16. **Your turn.** Enable a **file audit device** — Vault refuses to process a request if it can't write the audit log (fail-closed), the OSS analogue of Key Vault `AuditEvent` diagnostics. Look for a `vault audit enable file` invocation with a `file_path` pointing somewhere under `/vault/audit/`.
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

## Reference solution

Build it yourself first; check after.

### Part A — Deploy, seal & storage backend

```bash
vault status
vault operator raft list-peers
```

Optional seal/unseal cycle:
```bash
vault operator seal
vault status                      # Sealed true
vault operator unseal <share-1>
vault operator unseal <share-2>
vault operator unseal <share-3>
```

### Part B — Auth methods & policies

```bash
vault auth enable userpass
vault auth enable kubernetes
```

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

```bash
vault write auth/userpass/users/appdev password=devpass policies=app-ro
VAULT_TOKEN=$(vault login -token-only -method=userpass username=appdev password=devpass)
```

```bash
VAULT_TOKEN=$appdev_token vault token capabilities secret/data/app/config   # -> read
VAULT_TOKEN=$appdev_token vault token capabilities secret/data/other        # -> deny
```

### Part C — Dynamic database secrets

```bash
vault secrets enable database

vault write database/config/appdb \
    plugin_name=postgresql-database-plugin \
    allowed_roles="app" \
    connection_url="postgresql://{{username}}:{{password}}@postgres.oss500-secrets:5432/appdb?sslmode=disable" \
    username="vaultadmin" password="vaultadminpw"
```

```bash
vault write database/roles/app \
    db_name=appdb \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
                         GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="2m" max_ttl="10m"
```

```bash
vault read database/creds/app
# Key                Value
# lease_id           database/creds/app/AbCdEf...
# lease_duration     2m
# password           A1a-...
# username           v-userpass-app-XyZ...
```

```bash
PGPASSWORD='<password>' psql -h postgres.oss500-secrets -U 'v-userpass-app-XyZ...' -d appdb -c 'SELECT 1;'   # -> 1 row
```

```bash
vault lease revoke -prefix database/creds/app      # immediate revocation of every issued cred
PGPASSWORD='<password>' psql -h postgres.oss500-secrets -U 'v-userpass-app-XyZ...' -d appdb -c 'SELECT 1;'
# psql: FATAL: password authentication failed  (the role no longer exists)
```

### Part D — Rotation: root + static KV versions

```bash
vault write -f database/rotate-root/appdb
```
(After this, `vaultadminpw` is invalid; Vault stores the new password internally.)

```bash
vault kv put secret/app/config api_key=key-v1
vault kv put secret/app/config api_key=key-v2      # rotation event
vault kv get -version=1 secret/app/config          # old value still readable
vault kv metadata get secret/app/config            # shows version history + timestamps
```

(Optional) For a KV secret you want Vault to rotate *for* you, enable a **KV rotation** with a rotation schedule, or use the database engine's `rotation` on a static role (`vault write database/static-roles/...` with `rotation_period`). The pattern: Vault owns the credential and cycles it on a schedule; consumers always read "the current one."

### Part E — Audit devices

```bash
vault audit enable file file_path=/vault/audit/audit.log
```

```bash
vault kv get secret/app/config
tail -n 1 /vault/audit/audit.log | jq .
```

Note in the JSON: the request `path`, the `auth` block (which token/policy), the client IP, and that the **secret value is HMAC'd, not plaintext** — auditors see *that* the secret was accessed and *by whom*, without the log itself becoming a secret store. This is exactly what you'd forward to Loki/Wazuh (Phase 4) to alert on anomalous access — the Defender-for-Key-Vault analogue.

## Teardown

- `cd lab-infra/secrets && ./down.sh`

## What the exam asks

- Vault boots **sealed**; unsealing (Shamir key shares or auto-unseal) must precede any operation — the "Vault returns 503 / 'Vault is sealed'" scenario. Maps to how Key Vault/Managed HSM are protected by a root of trust you don't hold directly.
- **Dynamic vs static** secrets: dynamic credentials are generated per-request with a lease and are revocable/expiring — the preferred answer whenever the scenario says "credentials keep leaking" or "reduce standing access." Static secrets need explicit rotation.
- **Least privilege** in Vault = auth method (identity) + policy (path capabilities). A principal that can authenticate but has the wrong policy gets `permission denied` — distinguish an *authn* failure from an *authz* (policy) failure, just like `ForbiddenByRbac` vs a network deny in Key Vault.
- **Audit devices fail closed**: if no audit device can record a request, Vault blocks the request. "Enable diagnostics so who-accessed-what is logged" → audit device, forwarded to a SIEM.
- `rotate-root` means the operator deliberately gives up knowledge of the managing credential so only Vault holds it — a common "remove standing human access to the DB admin password" answer.
