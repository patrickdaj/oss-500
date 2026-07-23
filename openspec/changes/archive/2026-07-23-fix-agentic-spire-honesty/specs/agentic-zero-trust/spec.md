## ADDED Requirements

### Requirement: Agent SPIRE steps are either deployed or marked directions-only
The Domain 6 agent workload-identity (SPIRE) steps SHALL be either backed by a SPIRE server the `lab-infra/agentic/` component actually deploys, or clearly marked as walkthrough/directions-only — consistent with how the course marks other impractical-to-run pieces. No lab or note SHALL instruct the learner to interact with a SPIRE server (e.g. `exec` into `deploy/spire-server`) that no component deploys, and no lab SHALL claim SPIRE is "reused from Domain 1," where it was covered only as a walkthrough.

#### Scenario: No lab commands a SPIRE server that does not exist
- **WHEN** a learner runs `lab-infra/agentic/up.sh` and starts `labs/d6-identity.md`
- **THEN** either a SPIRE server is deployed and the run-it steps work, or the SVID-issuance steps are marked directions-only — in neither case does a step `exec` into a `spire-server` deployment that was never created

#### Scenario: Labs, notes, and plan agree on SPIRE's status
- **WHEN** a learner compares `labs/d6-identity.md`, `domains/6-agentic-zero-trust/d6-identity.md`, and `plan/phase6-agentic-zero-trust.md`
- **THEN** all three describe SPIRE's deployment status consistently (deployed, or directions-only) with no "already running / reused from Domain 1" claim contradicting the infra docs

#### Scenario: Directions are followable or honestly scoped out
- **WHEN** SPIRE stand-up is left as directions (`lab-infra/agentic/spire/registration.md`)
- **THEN** those directions are either a complete, followable install path, or an honest statement that standing up SPIRE is out of scope for the run-it path — not a single `entry create` command that presupposes an unbuilt server and agent
