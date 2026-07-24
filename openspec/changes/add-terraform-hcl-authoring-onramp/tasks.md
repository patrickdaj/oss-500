## 1. Author the hands-on Terraform exercise

- [x] 1.1 In `domains/0-fundamentals/05-git-iac-foundation.md`, add a hands-on "your first `terraform apply`" section: a ~10-line `main.tf` (kubernetes or kind provider) that creates a namespace, with `terraform init` → read the `plan` diff → `apply` → inspect `terraform.tfstate` → `destroy`.
- [x] 1.2 In the same section, name/demonstrate the authoring constructs the ZTNA labs reuse — `resource`, `variable`, `output`, attribute references, `sensitive`/`tfvars` — on the namespace example.
- [x] 1.3 Ensure any external links in the new section satisfy `resource-citation` (deep link + time estimate or `(reference)`), and `npm run lint:links` passes.

## 2. Fix the Phase-0 plan block

- [x] 2.1 In `plan/phase0-fundamentals.md`, point the Day 3/4 IaC block at the new hands-on exercise and budget ~1h for it.
- [x] 2.2 Correct the scope claim on `plan/phase0-fundamentals.md:29`: "every later lab is Terraform-automated" → "the ZTNA labs are Terraform-automated."
- [x] 2.3 Confirm no tracked objective or `tracker.yaml` entry changes (Domain 0 fundamentals are untracked).

## 3. Validation

- [x] 3.1 Run `openspec validate add-terraform-hcl-authoring-onramp --type change --strict` and confirm it passes.
