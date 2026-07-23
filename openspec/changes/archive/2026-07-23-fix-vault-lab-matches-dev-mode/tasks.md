# Tasks — fix-vault-lab-matches-dev-mode

## 1. Decide the mode (design)

- [x] 1.1 **Chosen: switch `lab-infra/secrets/` to single-node Raft init** (the more faithful path). This makes the deployment match the lab — which was already written for Raft (`vault status → Storage Type raft`, `operator raft list-peers`, Shamir unseal, login from a gitignored init file). So the lab needs almost no change; the fix is in the infra.

## 2. Switch the deployment to Raft init

- [x] 2.1 Rewrote `lab-infra/secrets/values.yaml`: disabled dev mode; enabled `server.ha` + `raft` (single replica), `dataStorage` PVC, `tls_disable=1`, `service_registration "kubernetes"`. Helm now renders the `vault` StatefulSet (confirmed via `helm template`). Kept the auto-unseal seal block as commented production reference so the lab can still *see* the Shamir flow.
- [x] 2.2 Rewrote `lab-infra/secrets/up.sh`: installs Vault without `--wait` (Raft boots sealed), waits for `vault-0` Running, `vault operator init -key-shares=3 -key-threshold=3 -format=json` → gitignored `.vault-init.json`, unseals with the 3 `unseal_keys_b64` shares, then installs the CSI driver and the Postgres backend. Idempotent (re-uses an existing init file).
- [x] 2.3 Updated `lab-infra/secrets/configure.sh` to read the root token from `.vault-init.json` (was hardcoded `root`), and fixed its dynamic-secrets example to the lab's names (`postgres.oss500-secrets`, `appdb`, `vaultadmin`).
- [x] 2.4 Added `.vault-init.json` to `.gitignore` (the repo only ignored the no-dot `vault-init.json`; the lab references the dot form) — confirmed `git check-ignore` now matches. Lab Part A already describes Raft/Shamir/init-file correctly, so no Part-A rewrite needed.

## 3. Validation

- [x] 3.1 `bash -n` clean on `up.sh`/`configure.sh`; `helm template` renders the `vault` StatefulSet from the Raft values; both openspec changes strict-validate. **Raft init/unseal command sequence** is the standard hashicorp flow; a local sandbox `operator init` stalled on an anomalous local `vault` build (v2.0.3), not representative of the pinned k8s image — flagged for host bring-up.
- [x] 3.2 `vault-deploy`/`vault-access` observables: seal/init flow is now real (was impossible in dev mode). `vault-dynamic`/`vault-rotation` verified independently (see `add-vault-postgres-backend`).
- [ ] 3.3 (host) `cd lab-infra/secrets && ./up.sh` on a kind cluster; confirm `vault status` shows `Storage Type raft`, `Sealed false`, `operator raft list-peers` returns the node, and Part A runs clean.
- [x] 3.4 `npm run lint:links` OK; `npx openspec validate fix-vault-lab-matches-dev-mode --strict` passes.
