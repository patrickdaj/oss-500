# Secure secrets and keys by using a secrets manager (Key Vault equivalent)

Domain 2, subsection 1 (`d2-secrets`). HashiCorp Vault is the open-source stand-in for Azure Key Vault, and like Key Vault it sits at the crossroads of identity (auth methods and policies), networking (its listener and audit trail), and data protection (encrypted storage and dynamic credentials). This is the heaviest subsection of the heaviest domain — get the seal/unseal, auth/policy, and dynamic-secret models cold. Primary labs: [d2-vault-dynamic-secrets](../../labs/d2-vault-dynamic-secrets.md) and [d2-vault-k8s-injection](../../labs/d2-vault-k8s-injection.md); environment in [`lab-infra/secrets/`](../../lab-infra/secrets/).

## Deploy a secrets manager and understand seal/unseal and storage backends

*Objective: `vault-deploy` · OSS: HashiCorp Vault ≈ SC-500: Azure Key Vault · Lab: [d2-vault-dynamic-secrets](../../labs/d2-vault-dynamic-secrets.md)*

Vault stores everything encrypted with a **master key**, which is itself encrypted by a **root key** (the "barrier"). At startup Vault is **sealed**: it has the ciphertext but not the key to decrypt it, so it can serve nothing until unsealed. `vault operator init` generates the root key, splits it with **Shamir's Secret Sharing** into N key shares (default 5) requiring a threshold (default 3) to reconstruct, and prints them once alongside the initial root token. `vault operator unseal` is then run repeatedly, each time supplying one share, until the threshold is met and Vault reconstructs the master key in memory.

```bash
vault operator init -key-shares=5 -key-threshold=3   # prints 5 unseal keys + root token, ONCE
vault operator unseal <share-1>                       # repeat with 3 distinct shares
vault operator unseal <share-2>
vault operator unseal <share-3>
vault status                                          # Sealed: false, HA mode, storage type
```

Manually entering shares after every restart doesn't scale, so production uses **auto-unseal**: Vault delegates the root-key wrap/unwrap to an external KMS (cloud KMS, an HSM via PKCS#11, or another Vault's **transit** engine). In this course the transit-based auto-unseal is exactly the pattern in [`keys-and-certificates.md`](keys-and-certificates.md) (`key-transit`). The **storage backend** holds the encrypted data: the modern default is **integrated storage (Raft)**, a self-contained consensus store needing no external dependency; the legacy option is **Consul**. `vault server -dev` runs an in-memory, auto-unsealed, single-share instance for learning only — never production.

Against SC-500, Vault plays Azure Key Vault: a managed vault you don't seal/unseal (Microsoft runs the HSM-backed barrier for you). The concepts still map — a Vault *namespace/mount* ≈ a Key Vault instance, and "vault-per-app-per-environment" is the same blast-radius guidance Azure gives.

Exam gotchas:

- Sealed Vault ≠ down Vault — it's running and reachable but refuses all secret operations until unsealed. A restarted pod comes back **sealed** unless auto-unseal is configured.
- The unseal threshold (e.g., 3-of-5) is *quorum to unseal*, not per-request. It reconstructs the root key once at unseal time.
- The initial root token and unseal shares are printed exactly once by `init`. Lose them with no auto-unseal and you cannot recover the data.
- `-dev` mode is in-memory and unsealed with a known root token — convenient, catastrophic in production.

**Resources:**
- [Vault seal/unseal concepts](https://developer.hashicorp.com/vault/docs/concepts/seal) (~15 min)
- [Integrated storage (Raft) backend](https://developer.hashicorp.com/vault/docs/configuration/storage/raft) (~15 min)
- [Auto-unseal with Transit](https://developer.hashicorp.com/vault/tutorials/auto-unseal/autounseal-transit) (~20 min)
- [`vault operator init` / Shamir key shares](https://developer.hashicorp.com/vault/docs/commands/operator/init) (~10 min)
- [Vault production hardening guide](https://developer.hashicorp.com/vault/tutorials/operations/production-hardening) (~25 min)

## Configure access with auth methods and policies

*Objective: `vault-access` · OSS: Vault auth methods / policies ≈ SC-500: Key Vault access model (RBAC) · Lab: [d2-vault-dynamic-secrets](../../labs/d2-vault-dynamic-secrets.md)*

Vault separates **authentication** (proving who you are → a token) from **authorization** (what that token may do → policies). **Auth methods** are pluggable identity front-doors mounted under `auth/`: `token` (built-in), `userpass`, `approle` (for machines with a role-id/secret-id pair), and — crucial for this course — `kubernetes`, which validates a pod's ServiceAccount JWT against the cluster's TokenReview API so workloads authenticate with the projected token they already have (the same token from [fundamentals](../0-fundamentals/02-kubernetes.md)).

**Policies** are HCL documents granting **capabilities** (`create`, `read`, `update`, `delete`, `list`, `sudo`, `deny`) on API **paths**. Everything in Vault is a path, so policy is path-based ACL. Default-deny is the rule: no matching grant means denied.

```hcl
# app-policy.hcl — read-only on one app's static secrets, generate dynamic DB creds
path "secret/data/app/*" {
  capabilities = ["read"]
}
path "database/creds/app-readonly" {
  capabilities = ["read"]
}
```

```bash
vault policy write app-policy app-policy.hcl
vault auth enable kubernetes
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc"
vault write auth/kubernetes/role/app \
  bound_service_account_names=app \
  bound_service_account_namespaces=oss500-apps \
  policies=app-policy ttl=1h
```

This is Vault's answer to the **Key Vault access model (Azure RBAC)**. Vault policies ≈ role definitions; the `bound_service_account_*` binding ≈ a role assignment to a managed identity. The SC-500 lesson "an app with Key Vault *Reader* can see metadata but not values" translates directly: a Vault policy with `list` but not `read` on a path shows keys but not their contents.

Exam gotchas:

- Auth (token issuance) and authz (policies) are distinct. Fixing "authenticated but can't read" means editing the *policy* bound to the role, not the auth method.
- Policies are default-deny and least-privilege by path. A `list` capability is not `read` — same distinction as Key Vault Reader vs Secrets User.
- The Kubernetes auth method trusts the cluster's TokenReview result, so the pod's ServiceAccount + namespace must match the role's `bound_service_account_*` exactly.
- The root token bypasses all policy — treat it like Key Vault's owner; revoke it after bootstrap and use scoped tokens.

**Resources:**
- [Vault policies concept](https://developer.hashicorp.com/vault/docs/concepts/policies) (~20 min)
- [Kubernetes auth method](https://developer.hashicorp.com/vault/docs/auth/kubernetes) (~15 min)
- [AppRole auth method (machine auth)](https://developer.hashicorp.com/vault/docs/auth/approle) (~15 min)
- [Vault tokens & the token concept](https://developer.hashicorp.com/vault/docs/concepts/tokens) (~15 min)
- [Policies tutorial (capabilities & least privilege)](https://developer.hashicorp.com/vault/tutorials/policies/policies) (~20 min)

## Issue dynamic, short-lived secrets with leases and revocation

*Objective: `vault-dynamic` · OSS: Vault dynamic secrets ≈ SC-500: Managed credentials / rotation · Lab: [d2-vault-dynamic-secrets](../../labs/d2-vault-dynamic-secrets.md)*

The headline feature that a plaintext Kubernetes Secret can never match: **dynamic secrets**. Instead of storing a database password, Vault holds admin credentials and *generates a brand-new, unique credential on demand* when an app reads it — then automatically deletes it when its **lease** expires. Every credential is short-lived, per-consumer, and individually revocable, so a leaked cred is useless in minutes and its blast radius is one workload.

```bash
vault secrets enable database
vault write database/config/appdb \
  plugin_name=postgresql-database-plugin \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/app?sslmode=disable" \
  allowed_roles="app-readonly" \
  username="vault-admin" password="…"
vault write database/roles/app-readonly \
  db_name=appdb \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl=1h max_ttl=24h

vault read database/creds/app-readonly    # returns a fresh username/password + lease_id + lease_duration
vault lease revoke <lease_id>             # kill this one credential immediately
vault lease revoke -prefix database/creds/app-readonly   # kill ALL creds from this role
```

Each read returns a **lease** (`lease_id`, `lease_duration`, `renewable`). Consumers renew before expiry or let it die; Vault runs the role's `revocation_statements` (default: `DROP ROLE`) to remove the DB user. This is the same value proposition as Azure **managed identities** and the "credentials you never see and never rotate manually" story — SC-500 frames Key Vault + managed identity as *eliminating* long-lived secrets; Vault dynamic secrets achieve it for databases, cloud IAM, SSH, PKI, and more.

Exam gotchas:

- Dynamic secrets are created at read time and destroyed at lease expiry — there is no long-lived password to steal or rotate.
- Revocation is granular: revoke one `lease_id`, or a whole prefix on incident. This is the containment answer for a compromised workload.
- `default_ttl`/`max_ttl` cap credential lifetime; a consumer must renew within TTL or re-fetch. Un-renewed leases are revoked automatically.
- The database secrets engine needs an admin connection Vault manages — protect *that* root credential (see `vault-rotation`).

**Resources:**
- [Vault leases, renewal & revocation](https://developer.hashicorp.com/vault/docs/concepts/lease) (~15 min)
- [Database secrets engine](https://developer.hashicorp.com/vault/docs/secrets/databases) (~20 min)
- [Dynamic secrets tutorial (PostgreSQL)](https://developer.hashicorp.com/vault/tutorials/db-credentials/database-secrets) (~20 min)
- [Your first dynamic secret (intro)](https://developer.hashicorp.com/vault/tutorials/get-started/understand-dynamic-secrets) (~10 min)

## Configure secret rotation for static and dynamic credentials

*Objective: `vault-rotation` · OSS: Vault rotation ≈ SC-500: Key Vault secret rotation · Lab: [d2-vault-dynamic-secrets](../../labs/d2-vault-dynamic-secrets.md)*

Rotation has three flavors in Vault. **Dynamic secrets rotate implicitly** — every lease produces a new credential, so "rotation" is just the natural TTL cycle. **Root-credential rotation** protects the privileged account Vault itself uses: `vault write -f database/rotate-root/appdb` changes the DB admin password to a value **only Vault knows** — after this, no human can log in as that admin, closing the "the bootstrap password is in someone's shell history" gap. **Static secrets** in the KV v2 engine are versioned, so writing a new value keeps history and lets you roll back, and the **static-roles** feature rotates a *fixed* database user on a schedule for legacy apps that need a stable username.

```bash
# Root rotation: Vault sets a new admin password nobody else knows
vault write -f database/rotate-root/appdb

# KV v2 static secret — every write is a new version, old versions retained
vault kv put secret/app/api-key value=s3cr3t-v2
vault kv get -version=1 secret/app/api-key    # roll back / audit prior value

# Static role: rotate a fixed DB user "reporting" every 24h automatically
vault write database/static-roles/reporting \
  db_name=appdb username=reporting rotation_period=24h
vault read database/static-creds/reporting     # current password for the fixed user
```

This mirrors **Key Vault secret rotation**. SC-500 stresses that Key Vault *secrets* don't auto-rotate (you wire up near-expiry events + a Function), whereas *keys* and *certificates* rotate by policy — and that dynamic/managed credentials remove the rotation burden entirely. Vault's split is analogous: dynamic and static-role rotation are automatic; KV static values are versioned but you decide when to change them.

Exam gotchas:

- After `rotate-root`, the new admin password is unknown to humans by design. Losing/rebuilding Vault means resetting that DB account out-of-band.
- Static-role rotation keeps a **stable username** (for apps that hardcode it) and rotates only the password on `rotation_period`; dynamic roles create a **new username** every time.
- KV v2 versioning is history/rollback, not automatic rotation — writing a new version is a manual/orchestrated act.
- The strongest rotation story is to not have a static secret at all: prefer dynamic secrets, matching the "use managed identities" answer on SC-500.

**Resources:**
- [Database root credential rotation](https://developer.hashicorp.com/vault/docs/secrets/databases#rotate-credentials) (~10 min)
- [KV v2 versioned secrets](https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2) (~15 min)
- [Database static roles & scheduled rotation](https://developer.hashicorp.com/vault/tutorials/db-credentials/database-creds-rotation) (~20 min)
- [KV v2 API — versioning & rollback](https://developer.hashicorp.com/vault/api-docs/secret/kv/kv-v2) (~10 min)

## Deliver secrets to workloads via the Vault agent injector or Secrets Store CSI

*Objective: `vault-k8s` · OSS: Vault Agent / CSI ≈ SC-500: Key Vault + workload identity · Lab: [d2-vault-k8s-injection](../../labs/d2-vault-k8s-injection.md)*

Getting a secret *into a pod* without baking it into the image or a Kubernetes Secret has two supported paths. The **Vault Agent Injector** is a mutating admission webhook (installed by the Vault Helm chart): annotate a pod and it injects a sidecar/init container that authenticates via the Kubernetes auth method, fetches the secret, and renders it to a file on a shared in-memory `emptyDir` volume — the app just reads the file, and the agent keeps it fresh as leases renew. Nothing lands in etcd.

```yaml
# Deployment pod template annotations — the injector does the rest
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "app"                       # the Kubernetes-auth role
    vault.hashicorp.com/agent-inject-secret-db: "database/creds/app-readonly"
    vault.hashicorp.com/agent-inject-template-db: |
      {{- with secret "database/creds/app-readonly" -}}
      DB_USER={{ .Data.username }}
      DB_PASS={{ .Data.password }}
      {{- end -}}
```

The alternative is the **Secrets Store CSI driver** with the Vault provider: secrets are mounted as a CSI volume at a filesystem path, and optionally *synced* into a native Kubernetes Secret for env-var consumption. CSI is a cross-provider standard (same driver fronts Vault, cloud secret stores, etc.); the injector is Vault-native and template-rich. Both avoid plaintext secrets in manifests.

This is precisely **Key Vault + workload identity** on Azure: a pod's federated identity authenticates to Key Vault, and either the CSI driver mounts the secret or the app SDK pulls it — no secret in the manifest. The Vault Kubernetes auth role ≈ the federated credential; the injected file ≈ the CSI mount.

Exam gotchas:

- The injector renders secrets to an **in-memory `emptyDir`**, never to etcd — a Kubernetes Secret would be only base64 (see [fundamentals](../0-fundamentals/02-kubernetes.md)).
- CSI can *optionally* sync to a K8s Secret; if you enable that, you've reintroduced an etcd-stored secret (encrypt etcd — see `data-encrypt`).
- The injector is a mutating webhook — pods only get sidecars if the annotation is present *and* the webhook is healthy.
- Both paths rely on the Kubernetes auth role's `bound_service_account_*` matching the pod's SA/namespace.

**Resources:**
- [Vault Agent Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector) (~20 min)
- [Injector annotations reference](https://developer.hashicorp.com/vault/docs/platform/k8s/injector/annotations) (~10 min)
- [Secrets Store CSI provider for Vault](https://developer.hashicorp.com/vault/docs/platform/k8s/csi) (~15 min)
- [Kubernetes Secrets Store CSI Driver (upstream)](https://secrets-store-csi-driver.sigs.k8s.io/) (~15 min)
- [Vault Secrets Operator (native CRD sync)](https://developer.hashicorp.com/vault/docs/platform/k8s/vso) (~15 min)

## Enable audit devices and monitor secret access

*Objective: `vault-audit` · OSS: Vault audit devices ≈ SC-500: Key Vault diagnostics / Defender for Key Vault · Lab: [d2-vault-dynamic-secrets](../../labs/d2-vault-dynamic-secrets.md)*

Every authenticated request and response in Vault can be recorded by an **audit device**. Vault supports `file`, `syslog`, and `socket` devices, and you can enable several at once. A critical safety property: **if no enabled audit device can log a request, Vault refuses the request** — auditing fails closed, so tampering with the log path denies service rather than blinding you silently.

```bash
vault audit enable file file_path=/vault/audit/audit.log
vault audit enable syslog tag="vault" facility="AUTH"    # ship to the host syslog / SIEM
vault audit list -detailed
```

Audit logs are JSON, one object per request/response, capturing timestamp, client token accessor, the request path and operation, remote address, and the policy result. Sensitive values (secret contents, tokens) are **HMAC-SHA256 hashed**, not plaintext — you can prove *that* secret X was accessed and correlate identical values across entries without the log itself leaking the secret. Ship these to the Domain 4 SIEM (Wazuh/OpenSearch) for detection, exactly as you'd forward Key Vault logs to Sentinel.

This is Vault's counterpart to **Key Vault diagnostic `AuditEvent` logs** (who-did-what → Log Analytics/Sentinel) and to **Defender for Key Vault**'s anomaly detection. Vault doesn't ship a built-in behavioral-anomaly engine like Defender, so on this stack the *detection* half lives in the SIEM layer that consumes these audit devices.

Exam gotchas:

- Auditing **fails closed** — a full disk or unreachable syslog on the *only* audit device blocks requests. Run at least two devices for resilience.
- Sensitive fields are HMAC'd, not plaintext; the log proves access patterns without exposing secret values. You can HMAC a known value with the audit device's key to search for it.
- Audit devices log requests/responses at the API boundary — enable them *before* you need forensics; they aren't retroactive.
- Detection/alerting on the OSS stack is the SIEM's job (Domain 4); Vault provides the telemetry, Wazuh/OpenSearch provides the "Defender-like" anomaly alerting.

**Resources:**
- [Vault audit devices](https://developer.hashicorp.com/vault/docs/audit) (~15 min)
- [File audit device](https://developer.hashicorp.com/vault/docs/audit/file) (~10 min)
- [Syslog audit device](https://developer.hashicorp.com/vault/docs/audit/syslog) (~10 min)
- [Blocked audit devices & fail-closed behavior](https://developer.hashicorp.com/vault/docs/concepts/audit) (~15 min)
- [Vault monitoring & telemetry](https://developer.hashicorp.com/vault/tutorials/monitoring/monitor-telemetry-audit-splunk) (~20 min)

## Summary

| Objective | Takeaway |
|---|---|
| `vault-deploy` | Sealed by default; `init` splits the root key (Shamir N-of-M), `unseal` reconstructs it; Raft storage, auto-unseal for prod, `-dev` never |
| `vault-access` | Auth methods issue tokens (kubernetes/approle/userpass); HCL policies grant path capabilities, default-deny, least-privilege |
| `vault-dynamic` | Per-consumer, short-lived credentials generated at read time with leases; revoke by lease_id or prefix — no static password to steal |
| `vault-rotation` | Dynamic rotates via TTL; `rotate-root` makes the admin password Vault-only; static-roles rotate a fixed user; KV v2 versions static values |
| `vault-k8s` | Agent Injector (annotations → in-memory file) or Secrets Store CSI (mounted volume) deliver secrets without plaintext in etcd |
| `vault-audit` | `file`/`syslog`/`socket` audit devices log HMAC'd request/response JSON; fails closed; feed the SIEM for Defender-style detection |
