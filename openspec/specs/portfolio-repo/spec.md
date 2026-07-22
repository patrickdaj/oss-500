# portfolio-repo Specification

## Purpose

OSS-500 doubles as a public work sample for Cloud and AI security roles. This capability defines the repo's portfolio requirements: it must be safe to publish (no secrets, credentials, or personal identifiers committed, with `*.example` templates instead) and it must present professionally, so an interviewer can grasp what it demonstrates and reproduce any lab within a screen of the root README.

## Requirements

### Requirement: Repo is public-portfolio safe
The repo SHALL be maintained under git from scaffold time and SHALL contain no secrets, credentials, tokens, or personal identifiers in committed content; generated cluster state, local kubeconfigs, `.env` files, Vault unseal keys/tokens, TLS private keys, and `node_modules/`/build output MUST be gitignored, with `*.example` templates provided instead.

#### Scenario: No sensitive values committed
- **WHEN** the repo history is scanned for secrets, tokens, or private keys
- **THEN** none are found; environment-specific values enter only via gitignored files or environment variables

#### Scenario: Example variables provided
- **WHEN** a stranger clones the repo and follows a lab
- **THEN** an `*.example` file (or documented variables list) tells them exactly what to supply

### Requirement: Portfolio-quality presentation
The root README SHALL present the repo as a professional Cloud and AI security work sample: what it demonstrates (OSS identity/secrets/Kubernetes/SIEM/AI-security engineering, IaC, structured self-directed learning, concept parity with SC-500), how it's organized, and how to reproduce any lab, plus a statement that the entire stack runs locally for $0.

#### Scenario: Readable by an interviewer
- **WHEN** a hiring manager or interviewer opens the repo root
- **THEN** within one screen they see what the project is, the skills it evidences, its SC-500 concept mapping, and clear navigation to labs, lab-infra, and notes
