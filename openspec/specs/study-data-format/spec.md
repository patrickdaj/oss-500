# study-data-format Specification

## Purpose

OSS-500's content is consumed by study-hub through its shared data model, so its machine-readable files must conform to that model rather than a bespoke shape. This capability defines the data formats: the tracker YAML shape study-hub ingests, the quiz-bank shape its validator checks, and the plan/reference conventions its parser and resolver read — so study-hub renders oss-500 without any course-specific data shape or linking code.

## Requirements

### Requirement: Tracker outline conforms to the study-hub shared model
The objective tracker's source of truth SHALL be `assessment/data/tracker.yaml` in the shape study-hub's shared model consumes: `domains[]`, each with a stable `id`, `name`, optional `weight`, and `subsections[]`; each subsection with a stable `id`, `name`, and a `notes` path pointing at an existing `domains/` markdown file; each objective with a stable unique `id`, `text` (the SC-500 skills-outline bullet), and `lab` type (`hands-on` | `walkthrough`). The tracker MAY carry additional fields (e.g., the OSS-equivalent tool) that the adapter ignores or folds into display. A human-readable `assessment/tracker.md` SHALL be generated alongside.

#### Scenario: Adapter ingests without a bespoke shape
- **WHEN** study-hub loads oss-500 via its adapter
- **THEN** every domain, subsection, objective, and notes path resolves into the shared `Tracker` model without a course-specific data shape

#### Scenario: Notes paths exist
- **WHEN** `lint:content` checks each subsection's `notes` path
- **THEN** the referenced `domains/` markdown file exists

### Requirement: Quiz banks conform to the study-hub quiz model
Each checkpoint quiz SHALL be authored as `assessment/data/quiz-<n>.yaml` matching study-hub's quiz model: `id`, `title`, `domain` (or `domains[]`), `passPercent`, and `questions[]`, where each question has a unique `id`, `stem`, `options[]` (≥2), `type` (`single` | `multi`), zero-based `answer` index(es) into `options`, `explanation`, an authoritative `docUrl`, and `objectiveIds` that all resolve to `tracker.yaml` ids.

#### Scenario: Valid question structure
- **WHEN** any quiz YAML is validated by study-hub's `lint:content`
- **THEN** every question has all required fields, `answer` indexes are in range, and every `objectiveIds` entry resolves to a tracker id

### Requirement: Plan and reference conventions match study-hub parsing
Plan day-blocks SHALL use the `- [ ] **[Nh] <block>** — details` task-list convention that study-hub's plan parser reads into phases/days/blocks, and in-content references SHALL use resolvable shapes — repo doc paths (`plan/`, `domains/`, `labs/`, `assessment/` markdown), `lab-infra/` component paths, and tracker objective ids — so study-hub's resolver renders them as live links and backlinks without oss-500 shipping any linking code.

#### Scenario: Plan blocks parse
- **WHEN** study-hub ingests a phase plan file
- **THEN** its day headings and `**[Nh]**` blocks parse into checkable plan blocks

#### Scenario: References resolve to live links
- **WHEN** a domain note or lab references an objective id or a `labs/`/`lab-infra/` path
- **THEN** study-hub's resolver renders it as an in-app link, and `lint:content` fails on any path-shaped reference that does not resolve
