# Tasks

## 1. Extract the shared ZTNA scaffolding

- [x] 1.1 Create `lab-infra/ztna-common/` with a shared bring-up/teardown wrapper carrying the invariant flow: `set -euo pipefail`, the tfvars-missing guard (`Copy terraform.tfvars.example -> terraform.tfvars ...`), and `terraform init -input=false` / `apply -input=false -auto-approve` / `destroy -input=false -auto-approve`.
- [x] 1.2 Add a shared `versions`/`terraform.tfvars.example` template for the common bits (`required_version = ">= 1.6"`, shared variable framing); leave provider-specific `required_providers`/`provider` blocks in each stack.
- [x] 1.3 Add a short `lab-infra/ztna-common/README.md` explaining the family pattern and stating that per-model logic lives in each stack's `main.tf`.

## 2. Repoint the four stacks

- [x] 2.1 `ztna-boundary/`: reduce `up.sh`/`down.sh` to thin callers of the shared wrapper, keeping only the per-model header and post-apply verify hint; repoint duplicated `versions`/`tfvars` boilerplate to the shared template. Leave `main.tf` untouched.
- [x] 2.2 `ztna-netbird/`: same repoint; keep `main.tf` untouched.
- [x] 2.3 `ztna-openziti/`: same repoint, keeping the per-model `rm -f host.jwt client.jwt` tail in its own `down.sh`; keep `main.tf` untouched.
- [x] 2.4 `ztna-pomerium/`: same repoint; keep `main.tf` untouched except for the namespace change in task 3.

## 3. Fix the Pomerium namespace

- [x] 3.1 Add an `oss500-ztna` namespace to `lab-infra/shared/namespaces.yaml` with `app.kubernetes.io/part-of: oss500` and the tightest `pod-security.kubernetes.io/enforce` profile Pomerium runs under (annotate inline if it must be relaxed, per the `oss500-security` precedent).
- [x] 3.2 Change `ztna-pomerium/main.tf` to target `oss500-ztna` with `create_namespace = false` (stop self-creating `ztna-pomerium`); update `variables.tf`/tfvars/README references if the namespace default is named there.

## 4. Verify

- [ ] 4.1 Run each stack's `up.sh` then `down.sh` and confirm it still brings up cleanly and tears down with no orphaned resources (Pomerium under the new namespace). (Blocked: requires live controllers — `boundary dev`, Vault, NetBird/Ziti control planes, and a kind cluster with Keycloak — not available in this environment. Verified statically instead: shellcheck clean, `terraform fmt`/`validate` pass, and the thin callers correctly reach the shared wrapper + guard.)
- [ ] 4.2 Confirm a single `kubectl get all -A -l app.kubernetes.io/part-of=oss500` returns the Pomerium resources (namespace/label scheme honored). (Blocked: requires a live cluster. Verified statically: `oss500-ztna` in namespaces.yaml carries `app.kubernetes.io/part-of: oss500`, and `main.tf` targets it with `create_namespace = false`.)
- [x] 4.3 Open each `ztna-*/main.tf` and confirm the per-model Terraform is still in place, unchanged, and readable without following an include (study value preserved).
- [x] 4.4 Run any lab-infra lint (shellcheck on the scripts, `terraform fmt -check`/`terraform validate` per stack) and fix findings.

## 5. Validate the change

- [x] 5.1 Run `openspec validate refactor-ztna-terraform-scaffolding --strict` and resolve any errors.
