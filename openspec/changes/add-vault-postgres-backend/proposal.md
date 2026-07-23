# Ship the Postgres backend the Vault dynamic-secrets lab requires

## Why

The `vault-dynamic` objective — arguably the single most important thing Vault does — is proven by watching Vault mint a **short-lived database credential** that Postgres accepts, then stops accepting after the lease expires or is revoked. `labs/d2-vault-dynamic-secrets.md` Part C walks exactly that: `vault write database/config/appdb …`, `vault read database/creds/app`, `psql -h postgres.oss500-secrets …`, watch the lease TTL expire, `vault lease revoke -prefix`.

**The Postgres it needs is never created.** The lab prereq claims "the component's `up.sh` deploys one, or apply `lab-infra/secrets/postgres.yaml`," but:

- `lab-infra/secrets/up.sh` installs only Vault + the Secrets Store CSI driver,
- **no `postgres.yaml` exists anywhere in the repo** (confirmed by search), and
- `lab-infra/secrets/configure.sh` punts with a comment: "The lab deploys the Postgres pod."

So `vault write database/config/appdb` fails its connection check, and `psql -h postgres.oss500-secrets` has neither a server to reach nor a psql-capable pod to run from. For this persona (Vault brand-new, DB plumbing unguided), Part C is a hard dead end on the headline feature. The `configure.sh`/lab namespace also disagree (`postgres.oss500-apps` vs `postgres.oss500-secrets`).

## What Changes

- Add `lab-infra/secrets/postgres.yaml`: a Postgres `Deployment` + `Service` (in `oss500-secrets`) seeded with the app/role database and a superuser Vault can use to create ephemeral roles, plus a small **psql-capable client** pod (or a documented `kubectl run … --image=postgres … -- psql` one-liner) so the learner can prove the credential works and then fails after revocation.
- Wire `up.sh` to apply it, and make `configure.sh` and the lab agree on one namespace/hostname (`postgres.oss500-secrets`).
- Update `labs/d2-vault-dynamic-secrets.md` Part C prereq to point at the now-real backend (remove the "or apply postgres.yaml" hedge).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `lab-infrastructure` — adds a requirement that a lab's prove-it observable is reproducible from the shipped component: every backend/service/client a lab's verification step references is created by that component's `up.sh` (or the lab's own steps), not assumed.

## Impact

- Affected specs: `lab-infrastructure` (one ADDED requirement).
- Affected content (at implementation time): new `lab-infra/secrets/postgres.yaml`, edits to `lab-infra/secrets/up.sh`, `configure.sh`, `README.md`, and `labs/d2-vault-dynamic-secrets.md` Part C.
- Pairs with `fix-vault-lab-matches-dev-mode` (same lab, Part A). Together they make the Vault lab followable end to end. Unblocks `vault-dynamic`.
