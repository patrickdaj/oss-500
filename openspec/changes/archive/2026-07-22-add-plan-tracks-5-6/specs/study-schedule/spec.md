## ADDED Requirements

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
