# Tasks — fix-vault-lab-matches-dev-mode

## 1. Decide the mode (design)

- [ ] 1.1 Confirm the direction: keep **dev mode** and reframe the narrative (recommended), or switch `lab-infra/secrets/` to a single-node **Raft init** that writes `.vault-init.json` and unseals. Record the choice; the tasks below assume dev mode.

## 2. Reframe Part A to match dev mode

- [ ] 2.1 In `labs/d2-vault-dynamic-secrets.md` Part A, state the lab Vault is dev mode: auto-unsealed, `inmem` storage, root token literally `root`. Remove the `.vault-init.json` login instruction.
- [ ] 2.2 Drop or reframe the `vault status → Storage Type raft`, `vault operator raft list-peers`, and Shamir `operator seal`/`unseal <share-N>` steps as **read-only production reference** (the commented Raft/HA block in `values.yaml`), marked as the `vault-deploy` walkthrough content.
- [ ] 2.3 Update `plan/phase2-secrets-data-networking.md` Day 1 so its seal/unseal + Raft framing matches (it currently reinforces the Shamir/Raft narrative).
- [ ] 2.4 Reconcile `lab-infra/secrets/vault-init.json.example` and `lab-infra/secrets/README.md` so nothing implies a generated `.vault-init.json` the lab depends on.

## 3. Validation

- [ ] 3.1 `cd lab-infra/secrets && ./up.sh`; run every Part-A command as written and confirm none errors or references a missing file (`vault login root`, `vault status`, policy write, `vault token capabilities`).
- [ ] 3.2 Confirm the `vault-deploy`/`vault-access` objectives' observables are still demonstrable in dev mode.
- [ ] 3.3 Run `npm run lint:links` and `npx openspec validate fix-vault-lab-matches-dev-mode --strict`.
