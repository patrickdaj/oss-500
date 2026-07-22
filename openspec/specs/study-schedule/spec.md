# study-schedule Specification

## Purpose

OSS-500 needs a study path calibrated to the SC-500 exam that fits a local, $0 lab stack. This capability defines the phased schedule under `plan/`: a fundamentals ramp followed by domain phases weighted to the SC-500 outline, a daily block structure fitting a defined budget with built-in slack, a local-resource readiness section replacing the source course's cloud-cost timeline, and a review phase that ends in a readiness gate with a full-stack capstone.

## Requirements

### Requirement: Phased learning path calibrated to SC-500 domain weights
The plan SHALL define a phased schedule under `plan/`: a Phase 0 fundamentals ramp (Linux, containers, Kubernetes basics, IaC primer) followed by domain phases sequenced in SC-500 outline order, with total time per domain roughly proportional to its SC-500 exam weight, and a final review phase. Each phase SHALL name its focus, its milestone, and a day-by-day breakdown.

#### Scenario: Phase plan exists per phase
- **WHEN** a reader opens `plan/` for any phase
- **THEN** they find a plan naming its focus (fundamentals ramp, an SC-500 domain with its weight percentage, or review), the phase milestone, and a day-by-day breakdown

#### Scenario: Fundamentals ramp precedes security content
- **WHEN** a reader opens the Phase-0 plan
- **THEN** it covers Linux/CLI, Docker/OCI images, Kubernetes primitives (pods, services, deployments, RBAC), Helm, and a k3s + IaC primer sufficient to stand up the lab cluster, and states it is a ramp — not the security curriculum

#### Scenario: Heaviest domain gets the most time
- **WHEN** comparing planned hours across domains
- **THEN** the secrets/data/networking domain (SC-500 weight 25–30%) receives more planned hours than any other domain

### Requirement: Daily structure fits a defined study budget
Each study day SHALL be broken into time-boxed blocks that alternate input (docs, videos, reading) and output (labs, notes, checkpoint questions), with a flex/review day per phase and a defined day off, using the `- [ ] **[Nh] <block>** — details` block convention that the UI parses.

#### Scenario: Day block breakdown
- **WHEN** a reader opens any study day in a phase plan
- **THEN** they see time-boxed blocks (with resource/lab references) summing to the day's target hours, formatted as parseable task-list checkboxes

#### Scenario: Slack is built in
- **WHEN** a study day overruns or is missed
- **THEN** the phase's flex day absorbs it without shifting subsequent phases

### Requirement: Schedule tracks local resources, not cloud cost
Because the lab stack runs locally on open-source software, the plan SHALL replace the source course's cloud cost/trial timeline with a local-resource readiness section: the minimum host resources (CPU/RAM/disk) each phase's lab stack requires and when to provision or tear down components to fit them, with an explicit statement that the full path costs $0 in software and requires no cloud account or expiring trial.

#### Scenario: Resource budget appears in-plan
- **WHEN** a reader follows the phase plans in order
- **THEN** each phase states the host resources its labs require and directs tearing down prior components not needed concurrently

#### Scenario: No cloud dependency
- **WHEN** a reader looks for cloud-account or trial-activation tasks
- **THEN** they find none; the plan states the entire course runs on a local machine or self-hosted homelab for $0

### Requirement: Review phase ends in a readiness gate
The final phase SHALL be a review/simulation phase that includes retaking checkpoint quizzes and a documented self-readiness rule tying missed questions back to tracker objectives, plus a capstone that stands up the full integrated lab stack end to end.

#### Scenario: Readiness gate stated
- **WHEN** a reader opens the review-phase plan
- **THEN** the readiness rule and the remediation loop for missed questions are explicitly described, and a full-stack capstone is defined
