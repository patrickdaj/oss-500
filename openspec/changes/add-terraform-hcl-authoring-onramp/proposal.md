## Why

Phase 0 teaches Terraform *conceptually* — `05-git-iac-foundation.md` covers providers, state, modules, and the write→plan→apply loop — but the learner never actually writes a line of HCL before Phase 1 Day 6, where the ZTNA labs demand from-scratch, multi-provider configs (`resource`/`variable`/`output`/`sensitive`/`tfvars`, attribute references). For the senior-network-engineer persona, the config-standards mindset transfers but blank-page HCL does not exist anywhere in Phase 0. The result (audit P4 / Part 5.2) is that the first `terraform apply` a learner ever runs is inside a heavy, self-estimated 2–3h broker lab — recall, not experience.

A second, smaller defect rides along: `plan/phase0-fundamentals.md:29` tells the learner "every later lab is Terraform-automated," which is false — only the ZTNA labs are. The overclaim sets a wrong expectation for the whole path.

## What Changes

- Add a ~1h hands-on **first `terraform apply`** exercise to the Phase-0 IaC foundation: a ~10-line `main.tf` (kubernetes or kind provider) that creates a namespace, driven through `init` → read the `plan` diff → `apply` → inspect `terraform.tfstate` → `destroy`. This converts P4 and the Phase-0 self-check's Terraform item from recall to experience, and is the blank-page authoring rep the ZTNA labs assume.
- Correct `plan/phase0-fundamentals.md:29`: "every later lab is Terraform-automated" → "the ZTNA labs are Terraform-automated," and point the Phase-0 IaC block at the new hands-on exercise.
- No new tracked objective and no `tracker.yaml` change (Domain 0 fundamentals are untracked reading); external links satisfy the `resource-citation` standard.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `git-iac-foundation`: adds a requirement that the Terraform foundation include a hands-on first-apply authoring exercise (write HCL → init → plan → apply → inspect state → destroy), not only the conceptual write→plan→apply description.
- `study-schedule`: adds a requirement that the Phase-0 IaC block schedule the hands-on first-apply exercise and describe the Terraform-automation scope accurately (the ZTNA labs, not "every later lab").

## Impact

- Affected specs: `git-iac-foundation` (one ADDED requirement), `study-schedule` (one ADDED requirement).
- Affected content (at implementation time): `domains/0-fundamentals/05-git-iac-foundation.md` (a hands-on authoring section), `plan/phase0-fundamentals.md` (the Day 3/4 IaC block wording + the corrected Terraform-automation scope sentence).
- Backs the Phase-0 self-check Terraform item and de-risks Phase 1 Day 6 ZTNA authoring (P4).
