# ztna-access-models Specification

## Purpose

oss-500 had Teleport PAM and NetworkPolicy/mesh but never completed the zero-trust access-model picture. This capability teaches zero-trust network access in Domain 1 as five open-source models sharing one NIST SP 800-207 principle — per-session, identity-based access to one resource with no standing network position — spanning broker, app-embedded overlay, identity-aware reverse proxy, and WireGuard mesh archetypes on top of the SPIFFE/SPIRE workload-identity substrate. Each new model gets a note and a reproducible local lab whose deploy is Terraform-automated where a provider exists, reusing existing infra, with no cloud account required.
## Requirements
### Requirement: The five ZTNA access models, as Terraform-automated code
Domain 1 SHALL teach zero-trust network access as five open-source models sharing one principle (per-session, identity-based access to one resource, no standing network position): **broker** (Teleport ✅, Boundary+Vault), **app-embedded overlay** (OpenZiti), **identity-aware reverse proxy** (Pomerium), and **WireGuard mesh** (Netbird), on top of the **SPIFFE/SPIRE** workload-identity substrate (✅). Each new model gets a note and a reproducible local lab whose deploy is **Terraform-automated** where a provider exists (Boundary, Vault, Netbird, OpenZiti edge), reusing existing infra where possible (Boundary reuses Vault). Adequate, correct coverage of each model is the bar — no cross-model comparison artifact is required.

#### Scenario: Each model is deployed by Terraform and verified locally
- **WHEN** a learner completes a ZTNA model lab
- **THEN** they deploy it from Terraform (or documented code where no provider exists) against the local stack, verify identity-based access to one resource with no broader network reach, and tear it down — no cloud account required

#### Scenario: The models are framed as one taxonomy
- **WHEN** a learner reads the ZTNA thread
- **THEN** each tool is placed by *model* (broker / overlay / proxy / mesh / workload-identity), mapped to the same NIST SP 800-207 principle, not presented as five unrelated products

### Requirement: A ZTNA lab provides the setup for any credential source it depends on
When a ZTNA lab's prove-it observable depends on an external credential source (such as Vault's SSH secrets engine), the lab SHALL provide the exact commands to enable and configure that source — even if the underlying tool is taught in full only in a later domain — and SHALL orient the learner that the sliver is intentionally front-loaded, with a pointer to where it is taught in depth.

#### Scenario: The Boundary lab sets up the Vault SSH engine it reads
- **WHEN** a learner reaches the injected-credential step of `labs/d1-ztna-boundary.md` having never used Vault
- **THEN** the lab supplies the exact `vault secrets enable ssh`, signing-role, and least-privilege-token commands at the path the Terraform reads, so the injected ephemeral SSH credential can be produced without independently learning Vault's SSH CA setup

#### Scenario: The front-loaded dependency is signposted
- **WHEN** the lab front-loads a slice of a later-domain tool (Domain-2 Vault)
- **THEN** it says so in one line and links the Domain-2 secrets notes, so the learner knows the sliver is expected here and taught in full later

#### Scenario: Reference and lab agree on injection vs brokering
- **WHEN** the learner compares their work to the reference `credentials-vault.tf`
- **THEN** the reference's vocabulary and resource names describe credential **injection** (matching the lab), not brokering

### Requirement: The access-models note teaches each model's resource chain in-note

`ztna-access-models.md` SHALL teach, in-note, the resource/object chain each of the four build-it-yourself Terraform labs constructs, so the note is a sufficient prerequisite rather than a table that outsources the real model to vendor provider docs. It SHALL include a per-model subsection for **Boundary** (scope → auth-method → host-catalog → host-set → target → role/grant), **OpenZiti** (identities, services, service/edge-router policies, enrollment), **Pomerium** (routes plus the policy schema binding an identity to a route), and **NetBird** (groups, setup-keys, policies). Each subsection SHALL name the objects and show the minimal chain the lab builds, following the Boundary lab's front-loaded-Vault box style, and SHALL mark each model's provider-registry documentation as load-bearing per the necessity-tag standard.

#### Scenario: A learner knows the object model before authoring HCL

- **WHEN** a learner reaches one of the four ZTNA Terraform labs (Boundary, OpenZiti, Pomerium, or NetBird)
- **THEN** `ztna-access-models.md` has already taught that model's resource chain, so the learner authors the configuration knowing what objects it creates and how they link — without the provider docs being the only real source

#### Scenario: Each model's load-bearing reference is signalled

- **WHEN** a learner reads a per-model subsection's resource list
- **THEN** that model's provider-registry doc is tagged as required reading, distinguishing it from enrichment links

