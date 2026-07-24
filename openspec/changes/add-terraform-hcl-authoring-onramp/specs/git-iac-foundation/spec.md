## ADDED Requirements

### Requirement: Phase 0 includes a hands-on first-apply authoring exercise
The Terraform foundation note SHALL include a hands-on exercise in which the learner *writes* a minimal HCL configuration (roughly ten lines, using the kubernetes or kind provider to create a namespace) and drives it through the full loop — `init` → read the `plan` diff → `apply` → inspect `terraform.tfstate` → `destroy` — so that a learner has authored HCL from a blank page before the Terraform-automated ZTNA labs demand it, rather than only having read the conceptual write→plan→apply description.

#### Scenario: The learner authors and applies HCL before the ZTNA labs
- **WHEN** a learner completes the Phase-0 IaC foundation
- **THEN** they have written a minimal `main.tf` themselves and run `init`/`plan`/`apply`/`destroy` against it, having inspected the resulting `terraform.tfstate`, so the first `terraform apply` they run is not inside a heavy Day-6 broker lab

#### Scenario: The exercise exercises the HCL constructs the ZTNA labs use
- **WHEN** the hands-on exercise is authored
- **THEN** it introduces the core authoring constructs the ZTNA configs assume — `resource`, `variable`, `output`, attribute references, and the notion of `sensitive`/`tfvars` inputs — at least by naming and demonstrating them on the namespace example
