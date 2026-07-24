## ADDED Requirements

### Requirement: Phase-0 IaC block schedules first-apply practice and states automation scope accurately
The Phase-0 plan SHALL schedule the hands-on first-`terraform apply` exercise as part of the IaC foundation block, and SHALL describe the course's Terraform-automation scope accurately — the ZTNA labs are Terraform-automated, not "every later lab."

#### Scenario: The Phase-0 IaC block points at the hands-on exercise
- **WHEN** a learner reads the Phase-0 IaC foundation block in `plan/phase0-fundamentals.md`
- **THEN** the block budgets time for and points at the write→init→plan→apply→inspect-state→destroy exercise, not only the conceptual foundation reading

#### Scenario: The Terraform-automation scope claim is correct
- **WHEN** the Phase-0 IaC block states which labs are Terraform-automated
- **THEN** it says the ZTNA labs are Terraform-automated rather than claiming "every later lab is Terraform-automated"
