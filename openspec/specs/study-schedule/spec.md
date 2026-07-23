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

#### Scenario: IaC primer links the git and Terraform foundation note
- **WHEN** a reader reaches the Phase-0 day that introduces the IaC loop
- **THEN** that day links `domains/0-fundamentals/05-git-iac-foundation.md` (the git model and Terraform write→plan→apply foundation) as reading to precede the applied kind/Helm work, and the phase self-check exercises the git working-tree/index/repo model and Terraform state/locking

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

### Requirement: Beyond-blueprint phases extend the path
The phased schedule under `plan/` SHALL provide a phase file for every domain in `assessment/data/tracker.yaml`, including the beyond-blueprint domains `d5` (offensive validation) and `d6` (agentic zero trust), sequenced after the four SC-500 domain phases and before the review phase. Each beyond-blueprint phase SHALL be named `phaseN-<slug>.md` (so study-hub's parser, which filters on `/(phase\d|review)/` and orders by `phase(\d+)`, renders it in sequence), name its focus and milestone, provide a day-by-day breakdown using the `- [ ] **[Nh] <block>** — details` convention, and link the domain's real notes, labs, and lab-infra. Beyond-blueprint phases carry no SC-500 exam weight; their day time is sized to objective depth rather than an exam percentage.

#### Scenario: Every tracker domain has a phase
- **WHEN** the set of `domains[].id` in `tracker.yaml` is compared to the `phaseN` files in `plan/`
- **THEN** every domain id `dN` has a corresponding `plan/phaseN-*.md` file, and study-hub's Plan view lists phases 5 and 6 ordered after phase 4 and before review

#### Scenario: Blocks parse and links resolve
- **WHEN** study-hub parses a beyond-blueprint phase file
- **THEN** each `- [ ]` item under a `## Day` heading becomes a checkable block with its parsed hour estimate, and every note/lab/lab-infra path it links resolves under `npm run lint:links`

### Requirement: Beyond-blueprint phases gate on their checkpoint
Each beyond-blueprint phase SHALL end on its domain checkpoint exactly as the SC-500 domain phases do: the final day directs taking `checkpoint-5`/`checkpoint-6` in test mode, and a score below the pass bar routes that day's remaining time to remediation, with each missed question mapping back to a tracker objective. Proof-of-work — the technique fires and its detection, authorization, or gating outcome is confirmed — remains the per-lab observable, distinct from the checkpoint phase gate.

#### Scenario: Checkpoint gates the beyond-blueprint phase
- **WHEN** a reader reaches the final day of phase 5 or phase 6
- **THEN** the plan directs taking that domain's checkpoint bank, and a below-bar score routes the synthesis/flex day to remediation before the path continues

#### Scenario: Overview reflects all phases
- **WHEN** `plan/overview.md` is read
- **THEN** its phase-map and resource tables list phases 5 and 6 before Review, and no sentence claims the plan has only six phases

### Requirement: Shared explanatory examples are stated once and referenced

A specific teaching example or cross-phase explanatory note used to justify a rule that applies across phases SHALL be stated once in a canonical location under `plan/` and referenced from other phase files, rather than copy-pasted near-verbatim into each. The intentional per-phase template — each phase's own footprint line, flex/last-day line, and end-of-lab teardown reminder (including the shared teardown label-selector command and the "resource killer" teardown phrasing) — is parallel structure by design and SHALL be preserved, not consolidated.

#### Scenario: A teaching example lives in one canonical place

- **WHEN** a reader compares the Falco "prove the control" example in `plan/overview.md` against `plan/phase3-compute-ai.md`
- **THEN** the example is stated once canonically in the overview's prove-the-control rule, and the phase file references that rule for its lab step rather than restating the Falco example verbatim

#### Scenario: A cross-phase note is not duplicated per phase

- **WHEN** a reader reads the beyond-blueprint checkpoint-gate framing across `plan/overview.md`, `plan/phase5-offensive-validation.md`, and `plan/phase6-agentic-zero-trust.md`
- **THEN** the shared framing (that a beyond-blueprint phase gates on its checkpoint exactly as the SC-500 phases do, with proof-of-work as the per-lab observable) appears once canonically, and each phase file adds only its phase-specific clause rather than repeating the whole framing near-verbatim

#### Scenario: Intentional per-phase template is preserved

- **WHEN** a reader opens any single phase file after consolidation
- **THEN** that phase still carries its own footprint line, its own flex/last-day line, and its own teardown reminder (including the `kubectl get all -A -l app.kubernetes.io/part-of=oss500` selector command), so the phase reads standalone and the parallel structure across phases is intact

#### Scenario: A consolidated reference resolves

- **WHEN** `npm run lint:links` runs after a phase file replaces a copied block with a reference to the canonical location
- **THEN** the reference resolves and the plan files pass link linting

### Requirement: Overview aggregate figures match source data
The plan overview under `plan/` SHALL state an objective total that equals the number of objective entries defined in `assessment/data/tracker.yaml` (summed across all domains `d1`–`d6`), so the overview never contradicts its cited source of truth.

#### Scenario: Objective total matches the tracker
- **WHEN** a reader compares the objective total stated in `plan/overview.md` against the count of objectives in `assessment/data/tracker.yaml`
- **THEN** the two figures are equal (currently 94)

#### Scenario: Adding tracker objectives keeps the overview in sync
- **WHEN** objectives are added to or removed from `assessment/data/tracker.yaml`
- **THEN** the objective total in `plan/overview.md` is updated to the new count so the stated figure still matches the source data

### Requirement: Every tracked objective is sequenced or explicitly optional
Every objective defined in `assessment/data/tracker.yaml` SHALL either be sequenced into a phase day in `plan/` (its note read and its lab performed or walkthrough studied), or be explicitly marked optional/beyond-plan and excluded from the readiness gate. The plan SHALL always be able to produce a green tracker by being followed as written.

#### Scenario: The fabric objective is reachable through the plan
- **WHEN** a learner follows `plan/` day by day
- **THEN** `d2-fabric` (and its `fab-*` subsections) is either sequenced into a Phase 2 day, or marked optional and excluded from the readiness gate — not left as a gate-required objective the plan never mentions

#### Scenario: No tracked objective is both unsequenced and gate-required
- **WHEN** an objective exists in `assessment/data/tracker.yaml`
- **THEN** it is referenced by a `plan/` phase, or flagged optional so the green-tracker readiness gate does not require it

#### Scenario: Following the plan yields a green tracker
- **WHEN** a learner completes every plan phase as written
- **THEN** every non-optional tracker objective has been covered, so the readiness gate's "every objective green" condition is satisfiable from the plan alone

