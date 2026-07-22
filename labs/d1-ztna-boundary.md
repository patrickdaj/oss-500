# Lab d1: Zero-Trust Access with HashiCorp Boundary + Vault *(beyond-blueprint)*

Broker identity-based, per-session access to **one** private host — with Vault injecting an **ephemeral** SSH credential the user never sees — defined entirely in Terraform. The broker ZTNA model (D1 `ztna-boundary`), as code.

**Objectives covered**

| id | Objective |
|---|---|
| `ztna-boundary` | Broker identity-based sessions with Vault-injected ephemeral credentials, Terraform-automated |

**SC-500 correspondence**: Microsoft Entra **Private Access** (Global Secure Access) + **PIM** — per-session, identity-gated access to a private resource with no standing network position. **Standards**: NIST SP 800-207 (PDP/PEP, per-session); the credential-injection step maps to ATT&CK **T1078 (Valid Accounts)** hardening.

**Prerequisites**
- Terraform ≥1.6; a local controller (`boundary dev`) and `vault server -dev` with the SSH secrets engine; a private SSH host the worker can reach. Stand up a throwaway target locally: `docker run -d --name ssh-target -e PASSWORD_ACCESS=true -e USER_NAME=labuser -e USER_PASSWORD=labpass -p 2222:22 lscr.io/linuxserver/openssh-server` — its address/port (`host.docker.internal`/`localhost` and `2222`) are the target host address and port you set in `terraform.tfvars`.
- Notes read: [`../domains/1-identity-governance/ztna-access-models.md`](../domains/1-identity-governance/ztna-access-models.md).

**Estimated time**: 2–3 h · $0 (local)

> **Directions-first.** Build the Terraform yourself from the steps below — that's the learning. A CI-validated **reference solution** lives in [`../lab-infra/ztna-boundary/`](../lab-infra/ztna-boundary/); use it to check your work (or `./up.sh` it to compare), not to copy.

## Challenge

Build, entirely in Terraform, a broker that gives one identity (`appuser`) a **per-session**, credential-injected path to **one** private SSH host — and nothing else.

Reach these observables (this is what `## Verification` will check):
- `appuser` can authenticate to the broker and open an SSH session to the target — but has **no network/IP route** to it directly. The worker proxies the one session; there is no standing network position to exploit.
- The SSH credential is **injected** by Vault at connect time — `appuser` never types it, sees it, or stores it, and it is short-lived (Vault's SSH secrets engine).
- `appuser` **cannot** reach any other host through the broker — the grant is least-privilege by construction, not by convention.

No solution below — just the shape of what "done" looks like. Build the Terraform yourself in the next section.

## Build it (guided)

### Part A — the broker (`ztna-boundary`)

Author Terraform (`hashicorp/boundary` provider) that creates, top-down, the org→project→identity→target→grant chain. Work through it in this order — each layer depends on the one before it:

1. **Scope it.** Create a `boundary_scope` **org**, then a **project** inside it. *Why*: zero trust starts by organizing resources under an identity-aware hierarchy, not by placing them on a flat, routable network.
2. **Create the identity.** Add a `boundary_auth_method` (type `password`) + `boundary_account_password` + `boundary_user` — this is your end-user, `appuser`. *Why*: the broker authorizes a **subject**, not an IP — this identity is what every later grant hangs off of.
3. **Model the target by identity, not address.** A `boundary_host_catalog_static` → `boundary_host_static` (the target's address) → `boundary_host_set_static`. *Hint*: the address lives on the `boundary_host_static` resource — nothing upstream of it needs to know it.
4. **Wrap it in a connectable target.** A `boundary_target` (type `tcp`, port 22) attached to the host set from step 3.
5. **Grant the narrowest thing that works.** A `boundary_role` granting `appuser` **only** `authorize-session` on that target — no `read`, no `list`, nothing else. *Why*: this single grant string is the least-privilege proof for the whole lab — if it grants more than `authorize-session`, the "cannot reach any other host" observable breaks.

**Your turn**: `terraform fmt`, `terraform init`, `terraform apply`. Before you apply, predict from the plan output exactly which resources should appear — if something unexpected shows up, you've over-granted somewhere.

### Part B — Vault credential injection

6. **Add a Vault-backed credential store and library.** A `boundary_credential_store_vault` + `boundary_credential_library_vault_generic`, pointed at Vault's SSH secrets engine.
7. **Wire it as *injection*, not brokering.** Attach the library to the target via **`injected_application_credential_source_ids`**. *Why the distinction matters*: brokered credentials are handed to the client (the user sees the secret); injected credentials are placed into the session by the worker — the client never sees it, and because it comes from Vault's SSH engine it's short-lived and unique per session.
8. **Re-apply.** *Your turn*: before you verify, write down what you'd expect to see (or not see) in your shell history / `boundary connect` output if the credential really was injected rather than typed — you'll check that prediction in `## Verification`.

## Verification
```bash
boundary authenticate password -login-name appuser
boundary connect ssh -target-id $(terraform output -raw target_id)
```
- `appuser` reaches the target with **no network/IP route** to it — the worker proxies one session.
- The credential was **injected** — never typed or seen; it's ephemeral (Vault SSH engine).
- The user **cannot** reach any other host — least privilege by default.
- Diff your config against [`../lab-infra/ztna-boundary/`](../lab-infra/ztna-boundary/).

## Reference solution
Build it yourself first; check after. The complete, CI-validated Terraform lives in [`../lab-infra/ztna-boundary/`](../lab-infra/ztna-boundary/):
- [`main.tf`](../lab-infra/ztna-boundary/main.tf) — the org/project scopes, the password auth-method + account + user, the static host catalog/host/host-set, the `tcp` target, and the least-privilege `boundary_role` granting only `authorize-session` (Part A, steps 1–5).
- [`credentials-vault.tf`](../lab-infra/ztna-boundary/credentials-vault.tf) — the `boundary_credential_store_vault` + `boundary_credential_library_vault_generic`, wired to the target via `injected_application_credential_source_ids` (Part B, steps 6–7).
- [`variables.tf`](../lab-infra/ztna-boundary/variables.tf) / [`terraform.tfvars.example`](../lab-infra/ztna-boundary/terraform.tfvars.example) — the inputs (Vault address/token, target host address, port) to fill in.
- [`up.sh`](../lab-infra/ztna-boundary/up.sh) / [`down.sh`](../lab-infra/ztna-boundary/down.sh) — `terraform init`/`apply` and `terraform destroy`, wrapping the same commands from Part A/B and `## Teardown`.
- [`README.md`](../lab-infra/ztna-boundary/README.md) — prereqs and run instructions for the component.

If your grant string allows anything beyond `authorize-session`, or you wired the credential source as *brokered* instead of *injected*, diff against `main.tf` / `credentials-vault.tf` to see exactly where it drifted.

## Teardown
```bash
terraform destroy     # or ../lab-infra/ztna-boundary/down.sh
# stop the `boundary dev` / `vault server -dev` processes
```

> **Validate it *(purple team)*.** Prove the broker *denies*: in [`d5-ztna-authz`](d5-ztna-authz.md), authenticate as `appuser`, try `authorize-session` on a target you have no role for, and try to reach the host IP directly — both must fail (**NIST 800-207** PEP; the negative test that would expose **ATT&CK T1078** over-grant).

## What the exam asks
SC-500 frames this as **Entra Private Access / Global Secure Access** (ZTNA to private apps) plus **PIM** (just-in-time, no standing access). The transferable concept: a **PDP** decides, a **PEP** brokers one session by identity, and privileged credentials are short-lived and never held by the user — the same principle whether the tool is Boundary or Entra.
