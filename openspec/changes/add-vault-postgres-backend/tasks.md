# Tasks — add-vault-postgres-backend

## 1. Ship the Postgres backend

- [ ] 1.1 Add `lab-infra/secrets/postgres.yaml`: a Postgres `Deployment` + `Service` in `oss500-secrets`, restricted-PSA compliant, with a seeded database and a superuser/owner role Vault's database secrets engine can use to create and drop ephemeral roles.
- [ ] 1.2 Provide a psql-capable client the lab can use — either a tiny client pod in `postgres.yaml`, or a documented `kubectl run pgclient --rm -it --image=postgres:16 -- psql …` one-liner in the lab.
- [ ] 1.3 Update `lab-infra/secrets/up.sh` to `kubectl apply -f postgres.yaml` (and wait for readiness) as part of bring-up.

## 2. Reconcile references

- [ ] 2.1 Make `lab-infra/secrets/configure.sh` and `labs/d2-vault-dynamic-secrets.md` agree on one host/namespace (`postgres.oss500-secrets`); remove the "The lab deploys the Postgres pod" punt.
- [ ] 2.2 Update the Part C prereq to point at the real backend (drop the "or apply `lab-infra/secrets/postgres.yaml`" hedge now that `up.sh` ships it) and note the psql client to use.
- [ ] 2.3 Update `lab-infra/secrets/README.md` to list Postgres as a shipped part of the secrets component.

## 3. Validation

- [ ] 3.1 `cd lab-infra/secrets && ./up.sh`; run Part C: `vault write database/config/appdb …` connects, `vault read database/creds/app` returns a credential.
- [ ] 3.2 Prove the control: `psql` with the dynamic credential succeeds; after `vault lease revoke -prefix database/creds/app` (or TTL expiry), the same credential is **rejected** by Postgres.
- [ ] 3.3 `cd lab-infra/secrets && ./down.sh`; confirm no orphaned Postgres resources.
- [ ] 3.4 Run `npm run lint:links` and `npx openspec validate add-vault-postgres-backend --strict`.
