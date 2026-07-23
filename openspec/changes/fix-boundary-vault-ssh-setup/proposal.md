# Provide the Vault SSH-engine setup the Boundary ZTNA lab depends on

## Why

`labs/d1-ztna-boundary.md` (Phase 1, Day 6) teaches the broker model, and its headline observable is an **injected, ephemeral SSH credential**: `appuser` connects through Boundary and Vault signs a short-lived SSH credential at connect time — the user never sees or stores it. The Terraform reads that credential from a Vault SSH secrets engine at `ssh/sign/boundary` (`lab-infra/ztna-boundary/credentials-vault.tf`, `variables.tf`).

But the lab and `up.sh` only say to run "`vault server -dev` **with the SSH secrets engine enabled**" — with **no commands** to enable/configure it. The learner must, unaided:

- `vault secrets enable ssh`,
- create a signing CA role at `ssh/sign/boundary` with the right allowed users/extensions,
- and mint a least-privilege token for Boundary's credential library.

This is a **forward dependency**: Vault is not taught until Domain 2, and configuring an SSH **CA signing** engine is non-trivial even for someone who knows Vault. For this persona (first Vault contact, no PKI-SSH-CA background), the injection observable is unreachable from the lab as written — the exact "figure out how it works / where to get it" trap the course is meant to avoid.

## What Changes

- Add the exact setup to `labs/d1-ztna-boundary.md` (and/or a small `lab-infra/ztna-boundary/vault-ssh-setup.sh`): `vault secrets enable ssh`, the `ssh/roles/boundary` (or `ssh/sign/boundary`) signing-role config, and the least-privilege token creation — everything the Terraform's `vault_ssh_path` assumes.
- Add a one-line orientation note that this **front-loads a slice of Domain-2 Vault**, with a pointer to the Domain-2 secrets notes, so the learner knows this Vault sliver is expected here and will be taught in full later.
- Reconcile the `credentials-vault.tf` header comment ("brokering"/`boundary_credential_library_vault`) with the lab's **injection** teaching and the `boundary_credential_library_vault_generic` resource the lab names, so the reference solution and lab agree.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `ztna-access-models` — adds a requirement that a ZTNA lab whose observable depends on a credential-source (e.g. Vault's SSH engine) provides the exact setup for that source, even when the underlying tool is taught in full in a later domain.

## Impact

- Affected specs: `ztna-access-models` (one ADDED requirement).
- Affected content (at implementation time): `labs/d1-ztna-boundary.md` (setup steps + orientation note), optional `lab-infra/ztna-boundary/vault-ssh-setup.sh`, and the `credentials-vault.tf` header comment.
- Unblocks the `ztna-boundary` injected-credential observable. Does not change the Domain-2 Vault curriculum.
