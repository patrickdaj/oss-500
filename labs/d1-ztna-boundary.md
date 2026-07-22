# Lab d1: Zero-Trust Access with HashiCorp Boundary + Vault *(beyond-blueprint)*

Broker identity-based, per-session access to **one** private host — with Vault injecting an **ephemeral** SSH credential the user never sees — defined entirely in Terraform. The broker ZTNA model (D1 `ztna-boundary`), as code.

**Objectives covered**

| id | Objective |
|---|---|
| `ztna-boundary` | Broker identity-based sessions with Vault-injected ephemeral credentials, Terraform-automated |

**SC-500 correspondence**: Microsoft Entra **Private Access** (Global Secure Access) + **PIM** — per-session, identity-gated access to a private resource with no standing network position. **Standards**: NIST SP 800-207 (PDP/PEP, per-session); the credential-injection step maps to ATT&CK **T1078 (Valid Accounts)** hardening.

**Prerequisites**
- Terraform ≥1.6; a local controller (`boundary dev`) and `vault server -dev` with the SSH secrets engine; a private SSH host the worker can reach.
- Notes read: [`../domains/1-identity-governance/ztna-access-models.md`](../domains/1-identity-governance/ztna-access-models.md).

**Estimated time**: 2–3 h · $0 (local)

> **Directions-first.** Build the Terraform yourself from the steps below — that's the learning. A CI-validated **reference solution** lives in [`../lab-infra/ztna-boundary/`](../lab-infra/ztna-boundary/); use it to check your work (or `./up.sh` it to compare), not to copy.

## Steps — build it yourself

### Part A — the broker (`ztna-boundary`)
Author Terraform (`hashicorp/boundary` provider) that creates, top-down:
1. A `boundary_scope` **org**, then a **project** inside it.
2. A `boundary_auth_method` (password) + `boundary_account_password` + `boundary_user` — your end-user.
3. A `boundary_host_catalog_static` → `boundary_host_static` (the target's address) → `boundary_host_set_static`.
4. A `boundary_target` (type `tcp`, port 22) attached to the host set.
5. A `boundary_role` granting the user **only** `authorize-session` on that target — nothing else (that's the least-privilege proof).

`terraform fmt`, `init`, `apply`.

### Part B — Vault credential injection
Add a `boundary_credential_store_vault` + `boundary_credential_library_vault_generic`, and wire it to the target via **`injected_application_credential_source_ids`** — *injected*, not brokered, so the client never sees the secret. Point the library at Vault's SSH secrets engine so the credential is short-lived and per-session. Re-apply.

## Verification
```bash
boundary authenticate password -login-name appuser
boundary connect ssh -target-id $(terraform output -raw target_id)
```
- `appuser` reaches the target with **no network/IP route** to it — the worker proxies one session.
- The credential was **injected** — never typed or seen; it's ephemeral (Vault SSH engine).
- The user **cannot** reach any other host — least privilege by default.
- Diff your config against [`../lab-infra/ztna-boundary/`](../lab-infra/ztna-boundary/).

## Teardown
```bash
terraform destroy     # or ../lab-infra/ztna-boundary/down.sh
# stop the `boundary dev` / `vault server -dev` processes
```

> **Validate it *(purple team)*.** Prove the broker *denies*: in [`d5-ztna-authz`](d5-ztna-authz.md), authenticate as `appuser`, try `authorize-session` on a target you have no role for, and try to reach the host IP directly — both must fail (**NIST 800-207** PEP; the negative test that would expose **ATT&CK T1078** over-grant).

## What the exam asks
SC-500 frames this as **Entra Private Access / Global Secure Access** (ZTNA to private apps) plus **PIM** (just-in-time, no standing access). The transferable concept: a **PDP** decides, a **PEP** brokers one session by identity, and privileged credentials are short-lived and never held by the user — the same principle whether the tool is Boundary or Entra.
