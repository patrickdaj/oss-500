# Tasks — add-vault-postgres-backend

## 1. Ship the Postgres backend

- [x] 1.1 Added `lab-infra/secrets/postgres.yaml`: a Postgres `Deployment` + `Service` in `oss500-secrets` (restricted-PSA compliant: runAsNonRoot/999, drop ALL caps, seccomp RuntimeDefault), seeded db `appdb` owned by admin `vaultadmin/vaultadminpw`, plus an initdb ConfigMap creating a demo `widgets` table so `GRANT SELECT` is meaningful.
- [x] 1.2 Added a `psql-client` Deployment (postgres:16-alpine, `sleep infinity`) in the same manifest; the lab runs `kubectl -n oss500-secrets exec deploy/psql-client -- env PGPASSWORD=… psql -h postgres.oss500-secrets …`.
- [x] 1.3 `lab-infra/secrets/up.sh` now `kubectl apply`s `postgres.yaml` and waits for `deploy/postgres` + `deploy/psql-client` readiness; `down.sh` deletes it.

## 2. Reconcile references

- [x] 2.1 `configure.sh` and `labs/d2-vault-dynamic-secrets.md` now agree on `postgres.oss500-secrets` / `appdb` / `vaultadmin`; removed the "The lab deploys the Postgres pod" punt and the `oss500-apps` mismatch.
- [x] 2.2 Updated the Part C prereq to point at the real backend (dropped the "or apply postgres.yaml" hedge) and named the `psql-client` pod + exact exec command.
- [x] 2.3 Noted Postgres + psql-client in the secrets component (`up.sh`/`down.sh` output + prereq); README self-containment covered by the up.sh bring-up messaging.

## 3. Validation

- [x] 3.1 **Verified end to end locally** (real `vault` + a `postgres:16-alpine` container matching `postgres.yaml`): the lab's Part C verbatim — `vault write database/config/appdb …` connects, `vault write database/roles/app …`, `vault read database/creds/app` issues a user.
- [x] 3.2 **Prove-the-control verified**: `psql` with the dynamic credential returned a row; after `vault lease revoke -prefix database/creds/app` the same credential got `password authentication failed`; and `rotate-root` invalidated the original `vaultadminpw`. `postgres.yaml` passes `kubectl apply --dry-run`.
- [ ] 3.3 (host) `cd lab-infra/secrets && ./down.sh`; confirm no orphaned Postgres/PVC resources on a real cluster.
- [x] 3.4 `npm run lint:links` OK; `npx openspec validate add-vault-postgres-backend --strict` passes.
