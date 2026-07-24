## ADDED Requirements

### Requirement: The access-models note teaches each model's resource chain in-note

`ztna-access-models.md` SHALL teach, in-note, the resource/object chain each of the four build-it-yourself Terraform labs constructs, so the note is a sufficient prerequisite rather than a table that outsources the real model to vendor provider docs. It SHALL include a per-model subsection for **Boundary** (scope → auth-method → host-catalog → host-set → target → role/grant), **OpenZiti** (identities, services, service/edge-router policies, enrollment), **Pomerium** (routes plus the policy schema binding an identity to a route), and **NetBird** (groups, setup-keys, policies). Each subsection SHALL name the objects and show the minimal chain the lab builds, following the Boundary lab's front-loaded-Vault box style, and SHALL mark each model's provider-registry documentation as load-bearing per the necessity-tag standard.

#### Scenario: A learner knows the object model before authoring HCL

- **WHEN** a learner reaches one of the four ZTNA Terraform labs (Boundary, OpenZiti, Pomerium, or NetBird)
- **THEN** `ztna-access-models.md` has already taught that model's resource chain, so the learner authors the configuration knowing what objects it creates and how they link — without the provider docs being the only real source

#### Scenario: Each model's load-bearing reference is signalled

- **WHEN** a learner reads a per-model subsection's resource list
- **THEN** that model's provider-registry doc is tagged as required reading, distinguishing it from enrichment links
