## ADDED Requirements

### Requirement: Lab commands match the component's deployed mode
A lab's step-by-step commands SHALL match the mode and configuration the backing `lab-infra/` component actually deploys, so a learner following the lab never runs an instruction the running tool contradicts or references a file the deployment never generates. Where production-only mechanics (e.g. Shamir seal/unseal, integrated Raft storage) are not exercised by the shipped dev deployment, the lab SHALL present them as read-only reference/walkthrough rather than as commands to run.

#### Scenario: The Vault dev deployment matches the lab narrative
- **WHEN** a learner runs `lab-infra/secrets/up.sh` (dev-mode Vault) and follows `labs/d2-vault-dynamic-secrets.md` Part A
- **THEN** the lab logs in with the dev root token `root`, does not instruct reading a `.vault-init.json` that is never generated, and does not require `raft` storage or Shamir shares that an in-memory dev server cannot provide

#### Scenario: Production seal/storage mechanics are framed as reference
- **WHEN** the lab covers Shamir seal/unseal and integrated Raft storage
- **THEN** these are presented as the commented production path (study material read alongside the dev deployment), not as commands the dev server is expected to execute
