# lab-infra/ztna-boundary — reference solution

The CI-validated Terraform **reference solution** for the Boundary+Vault ZTNA lab ([`../../labs/d1-ztna-boundary.md`](../../labs/d1-ztna-boundary.md)). Build your own from the lab directions first; run this to check or compare.

## What it provisions (Terraform)
`boundary_scope` org→project · a password auth-method + account + user · a static host/host-set/target (SSH) · a least-privilege role granting **only** `authorize-session` · a `boundary_credential_store_vault` + library wired to the target via `injected_application_credential_source_ids` (credential **injection** — the client never sees the secret; Vault's SSH engine makes it ephemeral).

## Prereqs
- Terraform ≥1.6; providers `hashicorp/boundary`, `hashicorp/vault`.
- A controller: `boundary dev` (local all-in-one). A Vault dev server: `vault server -dev` with the SSH secrets engine enabled.
- A private SSH host the worker can route to.

## Run
```bash
cp terraform.tfvars.example terraform.tfvars   # fill in addrs/creds/target (gitignored)
./up.sh        # terraform init + apply, prints the verify commands
./down.sh      # terraform destroy
```
Deploy → verify identity-based, credential-injected access to one host → tear down. $0, local, no cloud account.
