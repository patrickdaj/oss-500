# git-iac-foundation Specification

## Purpose

The course leans hard on git and Terraform — the ZTNA labs are Terraform-automated and `gov-iac` is a tracked objective — yet Phase 0 (Domain 0 fundamentals) had no dedicated foundation for either: `03-kind-helm-iac.md` covered Terraform only at intro depth and there was no git note at all. This capability adds one Phase 0 fundamentals note (`domains/0-fundamentals/05-git-iac-foundation.md`) establishing a git foundation (the version-control model, commits/branches/remotes, repo-as-source-of-truth / GitOps) and a Terraform foundation (providers, state + locking, modules, write → plan → apply), each framed as the groundwork the IaC-automated labs and `gov-iac` assume. It is cross-linked with `03-kind-helm-iac.md`, adds no tracked objective or `tracker.yaml` change (Domain 0 fundamentals are untracked reading), and its external links satisfy the `resource-citation` standard.
## Requirements
### Requirement: Phase 0 has a git foundation
Domain 0 (fundamentals) SHALL include a note establishing git foundations — the version-control model, commits/branches/remotes, and the repository as the source of truth for infrastructure (GitOps / change management) — sufficient for a learner to work in the course's lab repositories.

#### Scenario: A learner gains git grounding before the automated labs
- **WHEN** the Phase 0 fundamentals are read
- **THEN** a note covers the git model and the repo-as-source-of-truth idea, and the learner can operate the version control the later labs assume

### Requirement: Phase 0 has a Terraform / IaC foundation
The same note SHALL establish Terraform foundations — providers, state and locking, modules, and the write → plan → apply workflow — as the groundwork the course's Terraform-automated labs and the `gov-iac` objective assume, cross-linked from `03-kind-helm-iac.md`.

#### Scenario: A learner is prepared for the IaC-automated labs
- **WHEN** a learner reaches the Terraform-automated ZTNA labs or `gov-iac`
- **THEN** the foundation note has already covered Terraform state, modules, and the plan/apply workflow, and `03-kind-helm-iac.md` links to it as its underpinning

### Requirement: The foundation note preserves course invariants
Adding the note SHALL NOT change any tracked objective, `tracker.yaml`, or study-hub domain/objective counts (Domain 0 fundamentals are untracked reading), and its external links SHALL satisfy the `resource-citation` standard.

#### Scenario: No tracked coverage changes and links pass lint
- **WHEN** the note is added and `npm run lint:links` runs
- **THEN** the tracker and objective ids are unchanged and the link lint passes (deep links or `(reference)`)

### Requirement: Phase 0 includes a hands-on first-apply authoring exercise
The Terraform foundation note SHALL include a hands-on exercise in which the learner *writes* a minimal HCL configuration (roughly ten lines, using the kubernetes or kind provider to create a namespace) and drives it through the full loop — `init` → read the `plan` diff → `apply` → inspect `terraform.tfstate` → `destroy` — so that a learner has authored HCL from a blank page before the Terraform-automated ZTNA labs demand it, rather than only having read the conceptual write→plan→apply description.

#### Scenario: The learner authors and applies HCL before the ZTNA labs
- **WHEN** a learner completes the Phase-0 IaC foundation
- **THEN** they have written a minimal `main.tf` themselves and run `init`/`plan`/`apply`/`destroy` against it, having inspected the resulting `terraform.tfstate`, so the first `terraform apply` they run is not inside a heavy Day-6 broker lab

#### Scenario: The exercise exercises the HCL constructs the ZTNA labs use
- **WHEN** the hands-on exercise is authored
- **THEN** it introduces the core authoring constructs the ZTNA configs assume — `resource`, `variable`, `output`, attribute references, and the notion of `sensitive`/`tfvars` inputs — at least by naming and demonstrating them on the namespace example

