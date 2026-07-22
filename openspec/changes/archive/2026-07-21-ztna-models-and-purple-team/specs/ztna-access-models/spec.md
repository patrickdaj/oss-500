# Spec: ztna-access-models

## ADDED Requirements

### Requirement: The five ZTNA access models, as Terraform-automated code
Domain 1 SHALL teach zero-trust network access as five open-source models sharing one principle (per-session, identity-based access to one resource, no standing network position): **broker** (Teleport ✅, Boundary+Vault), **app-embedded overlay** (OpenZiti), **identity-aware reverse proxy** (Pomerium), and **WireGuard mesh** (Netbird), on top of the **SPIFFE/SPIRE** workload-identity substrate (✅). Each new model gets a note and a reproducible local lab whose deploy is **Terraform-automated** where a provider exists (Boundary, Vault, Netbird, OpenZiti edge), reusing existing infra where possible (Boundary reuses Vault). Adequate, correct coverage of each model is the bar — no cross-model comparison artifact is required.

#### Scenario: Each model is deployed by Terraform and verified locally
- **WHEN** a learner completes a ZTNA model lab
- **THEN** they deploy it from Terraform (or documented code where no provider exists) against the local stack, verify identity-based access to one resource with no broader network reach, and tear it down — no cloud account required

#### Scenario: The models are framed as one taxonomy
- **WHEN** a learner reads the ZTNA thread
- **THEN** each tool is placed by *model* (broker / overlay / proxy / mesh / workload-identity), mapped to the same NIST SP 800-207 principle, not presented as five unrelated products
