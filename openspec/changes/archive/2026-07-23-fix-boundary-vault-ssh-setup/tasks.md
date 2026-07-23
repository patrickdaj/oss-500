# Tasks — fix-boundary-vault-ssh-setup

## 1. Provide the Vault SSH-engine setup

- [x] 1.1 Added a **"Setup — Vault's SSH secrets engine (do this first)"** block to `labs/d1-ztna-boundary.md`: `vault secrets enable ssh`, `vault write ssh/config/ca generate_signing_key=true`, the `ssh/roles/boundary` CA signing role (permit-pty, allowed users, 5m TTL) at the path the Terraform reads, plus a least-privilege `boundary-ssh` policy + scoped token for `vault_token`. **Verified locally** against a real `vault server -dev`: enable → config/ca → role → `ssh/sign/boundary` produces a short-lived signed user cert.
- [ ] 1.2 (Optional) Capture the above in `lab-infra/ztna-boundary/vault-ssh-setup.sh` — deferred; the commands are inline in the lab and copy-paste runnable.
- [x] 1.3 Added an orientation note that this front-loads a slice of Domain-2 Vault, linking `plan/phase2` and `domains/2-secrets-data-networking/secrets-management.md`. Also added the **target-must-trust-the-CA** callout (`vault read -field=public_key ssh/config/ca` → `TrustedUserCAKeys` on the target's sshd) — the missing step that makes a valid injected cert actually authenticate.

## 2. Reconcile the reference with the lab

- [x] 2.1 Fixed `lab-infra/ztna-boundary/credentials-vault.tf`: header now says **injection** (not "brokering"). While reconciling the resource name, found the lab's `boundary_credential_library_vault_generic` is **not a valid resource** for the pinned provider (`hashicorp/boundary` v1.6.0 exposes `boundary_credential_library_vault`, `_ldap`, `_ssh_certificate` — no `_generic`); corrected the lab to `boundary_credential_library_vault` to match the reference. `terraform validate` now passes.

## 3. Validation

- [x] 3.1 Vault half verified locally (SSH CA signing produces the ephemeral cert); `terraform validate` passes on the corrected stack. Full `boundary dev` + `terraform apply` + `boundary connect` still to be run on the host (needs a target whose sshd trusts the Vault CA — see the new callout).
- [ ] 3.2 (host) Prove the observable: connect through Boundary to the CA-trusting SSH target; confirm the SSH credential is injected (never typed/stored) and short-lived.
- [x] 3.3 `npm run lint:links` OK; `npx openspec validate fix-boundary-vault-ssh-setup --strict` passes.

## 4. Follow-up flagged for host verification

- [ ] 4.1 Consider `boundary_credential_library_vault_ssh_certificate` (purpose-built for SSH cert injection: Boundary generates the keypair and calls the sign endpoint) vs. the generic library + `ssh/sign/boundary` POST currently used — validate which actually injects a working cert during a live `boundary connect` before finalizing.
