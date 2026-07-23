# hands-on-labs Specification

## Purpose

OSS-500 teaches SC-500 concepts by proving their open-source equivalents in runnable labs. This capability defines the lab catalog and lab format: every skills-outline subsection maps to at least one lab, each lab follows a standard structure with a concrete verification step, every lab names the SC-500 control it corresponds to, and topics impractical to run locally are covered by explicitly-marked walkthrough labs.
## Requirements
### Requirement: Lab catalog covers every objective subsection
The repo SHALL provide a lab catalog under `labs/` where every skills-outline subsection maps to at least one lab, with a catalog index (`labs/README.md`) presenting a table that maps each subsection (tracker id) to its lab(s), the lab type (hands-on / walkthrough), and the OSS component(s) it exercises.

#### Scenario: Catalog index maps objectives to labs
- **WHEN** a reader opens `labs/README.md`
- **THEN** they see a table mapping each skills-outline subsection to its lab(s), the lab type, and the OSS tool(s) used

#### Scenario: Full objective coverage
- **WHEN** the catalog is compared against `assessment/data/tracker.yaml`
- **THEN** every objective subsection resolves to at least one catalog entry

### Requirement: Custom labs follow a standard format
Each lab SHALL state: objectives covered (mapped to tracker ids), prerequisites (which `lab-infra/` components to bring up and which domain notes to read first), estimated time, deploy/config steps, a verification step proving the security control works, and teardown instructions.

#### Scenario: Custom lab structure
- **WHEN** a reader opens any lab under `labs/`
- **THEN** it contains all sections: objectives, prerequisites, estimated time, steps, verification, teardown

#### Scenario: Verification is concrete
- **WHEN** a lab's steps are completed
- **THEN** the verification section gives an observable check (e.g., a denied Kyverno admission, a fired Falco alert, an OIDC token rejected, a Trivy CRITICAL finding, a NetworkPolicy-blocked connection) that confirms the security control functions

### Requirement: Labs teach the SC-500 concept through the OSS tool
Each lab SHALL name the SC-500 control it corresponds to and prove the equivalent control in the OSS stack, so completing the lab evidences the transferable concept (e.g., "Conditional Access" via Keycloak authorization policies; "Azure Policy for AKS" via Kyverno/Gatekeeper; "Microsoft Sentinel analytics rule" via a Wazuh/Sigma detection).

#### Scenario: Concept correspondence stated
- **WHEN** a reader opens any lab
- **THEN** it names the SC-500 control it maps to and its verification proves the OSS equivalent enforces the same security outcome

### Requirement: Walkthrough labs for components impractical to run locally
Topics whose full hands-on practice is impractical on a single host (e.g., multi-node HSM integration, large-scale service mesh) SHALL be covered by walkthrough labs — written configuration sequences with docs and reference output — and explicitly marked `walkthrough` in the catalog; everything runnable on a laptop-class host SHALL be `hands-on`.

#### Scenario: Walkthrough marking
- **WHEN** a topic cannot be practiced hands-on on the reference host
- **THEN** its catalog entry is marked `walkthrough` and the lab still enumerates the exact configuration steps as if performing them

### Requirement: Lab commands match the component's deployed mode
A lab's step-by-step commands SHALL match the mode and configuration the backing `lab-infra/` component actually deploys, so a learner following the lab never runs an instruction the running tool contradicts or references a file the deployment never generates. Where production-only mechanics (e.g. Shamir seal/unseal, integrated Raft storage) are not exercised by the shipped dev deployment, the lab SHALL present them as read-only reference/walkthrough rather than as commands to run.

#### Scenario: The Vault dev deployment matches the lab narrative
- **WHEN** a learner runs `lab-infra/secrets/up.sh` (dev-mode Vault) and follows `labs/d2-vault-dynamic-secrets.md` Part A
- **THEN** the lab logs in with the dev root token `root`, does not instruct reading a `.vault-init.json` that is never generated, and does not require `raft` storage or Shamir shares that an in-memory dev server cannot provide

#### Scenario: Production seal/storage mechanics are framed as reference
- **WHEN** the lab covers Shamir seal/unseal and integrated Raft storage
- **THEN** these are presented as the commented production path (study material read alongside the dev deployment), not as commands the dev server is expected to execute

