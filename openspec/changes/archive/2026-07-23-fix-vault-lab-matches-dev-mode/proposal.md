# Reconcile the Vault lab narrative with the deployed dev-mode Vault

## Why

Phase 2 Day 1 is the learner's **first contact with Vault**, and every Part-A instruction contradicts what `lab-infra/secrets/` actually deploys.

`lab-infra/secrets/values.yaml` sets `server.dev.enabled: true` with `devRootToken: "root"` — an in-memory, auto-unsealed, `inmem`-storage Vault with a fixed root token and **no init output and no Shamir shares**; the Raft/HA blocks are present only as commented production reference. But `labs/d2-vault-dynamic-secrets.md` Part A tells the learner to:

- `vault login <root-token>` read "from the gitignored `secrets/.vault-init.json`" — a file **nothing generates** (only a `vault-init.json.example` exists),
- expect `vault status` to show `Storage Type raft`,
- run `vault operator raft list-peers` (errors on `inmem`), and
- walk a Shamir `operator seal` / `unseal <share-N>` cycle that is impossible with zero shares.

For a learner who is rusty and brand-new to Vault, this is a maximal time-sink: the tool's own output contradicts every step. The teaching content on seal models (Shamir vs auto-unseal), Raft, and init is valuable — it just needs to match the environment the student is actually driving.

## What Changes

Reconcile the lab with reality. The recommended (lowest-friction) path is to **keep dev mode** and reframe Part A:

- State plainly that the lab Vault runs in **dev mode**: it auto-unseals, uses in-memory storage, and its root token is literally `root` (no `.vault-init.json` to hunt for).
- Present Shamir seal/unseal, Raft integrated storage, and `operator init` as the **commented production path** in `values.yaml` — study material read alongside, not commands the dev server can execute — and mark that reading as the `vault-deploy` walkthrough content, consistent with how the course handles other impractical-to-run-locally pieces.
- Remove the `.vault-init.json` login instruction (or, if the team prefers to keep a real init story, switch the component to a single-node Raft init whose `up.sh` actually writes `.vault-init.json` and unseals — a larger change, noted as the alternative in `design`).
- Fix the stray `vault-init.json.example` framing so it doesn't imply a generated file the lab depends on.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `hands-on-labs` — adds a requirement that a lab's step-by-step commands match the deployment mode the component actually ships, so the learner never follows instructions the running tool contradicts.

## Impact

- Affected specs: `hands-on-labs` (one ADDED requirement).
- Affected content (at implementation time): `labs/d2-vault-dynamic-secrets.md` Part A + prereqs, `lab-infra/secrets/README.md`, and `plan/phase2-secrets-data-networking.md` Day 1 wording (which repeats the Raft/Shamir framing).
- Pairs with `add-vault-postgres-backend` (the same lab's Part C blocker). Together they make the Vault lab followable end to end.
