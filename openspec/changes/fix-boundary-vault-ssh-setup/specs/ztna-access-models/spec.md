## ADDED Requirements

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
