# study-hub-integration Specification

## Purpose

OSS-500 ships content only; study-hub provides the study application. This capability defines the integration: oss-500 is mounted into study-hub as a git submodule (never copied, no ported app), a thin per-course adapter normalizes it into the shared `Course` model, a single registry entry wires it into the course switcher, and its `lab-infra/*/README.md` files are ingested as in-app docs following the scc-500 model — with study-hub's validation and tests staying green.

## Requirements

### Requirement: oss-500 is consumed by study-hub as a content submodule
oss-500 SHALL be added to `../study-hub` as a git submodule at `content/oss-500` (registered in `.gitmodules`) so its content is sourced, never copied, and pointer-bumped via `git submodule update --remote content/oss-500`. oss-500 SHALL NOT contain its own study application.

#### Scenario: Submodule mounts the content
- **WHEN** study-hub's submodules are initialized
- **THEN** `content/oss-500` mounts the oss-500 repo and study-hub's build-time globs ingest its `plan/`, `domains/`, `labs/`, and `assessment/data/` files

#### Scenario: No duplicate app
- **WHEN** the oss-500 repo is inspected
- **THEN** it contains no `ui/` app, no ported rendering/tracking/quiz code, and no copy of study-hub

### Requirement: A per-course adapter normalizes oss-500 into the shared model
A thin adapter SHALL exist at `../study-hub/src/content/adapters/oss500.ts` that produces the shared `Course` model from oss-500's raw files, deriving from the scc-500 adapter where the data shape matches (nested `domains → subsections → objectives`, `tracker.yaml`, `quiz-*.yaml`). Its `CourseConfig` SHALL set `id: "oss-500"`, a `label` and `tagline`, and `weekPaced: false` so the Azure trial-clock and week-schedule widgets do not render for this course.

#### Scenario: Content renders through the shared UI
- **WHEN** a user selects oss-500 in study-hub's course switcher
- **THEN** the dashboard, plan, notes, labs, tracker, and quizzes render from oss-500 content with no course-specific UI branching

#### Scenario: Trial widgets suppressed
- **WHEN** the oss-500 dashboard renders
- **THEN** no cloud cost/trial-window countdown is shown, because `weekPaced` is false

### Requirement: oss-500 is registered and passes study-hub validation
A single entry SHALL be added to `../study-hub/src/content/registry.ts` mapping `oss-500` to its adapter, and study-hub's `npm run lint:content` and test suite SHALL pass with oss-500 present.

#### Scenario: Registered in the switcher
- **WHEN** study-hub builds with the registry entry added
- **THEN** oss-500 appears in the course switcher and routes under `/oss-500/*`

#### Scenario: Validation stays green
- **WHEN** `npm run lint:content` runs in study-hub with the oss-500 submodule present
- **THEN** it passes with no unresolved objective ids, missing notes paths, or out-of-range answers for oss-500

### Requirement: Lab-infra READMEs are browsable in-app, following the scc-500 model
Mirroring how study-hub ingests scc-500's `terraform/*/README.md` files as in-app docs, study-hub SHALL ingest oss-500's `lab-infra/*/README.md` files: a `content/*/lab-infra/*/README.md` glob SHALL be added to `../study-hub/src/content/raw.ts`, and the `oss500` adapter SHALL surface them as browsable, searchable docs and as valid link targets for `lab-infra/` references.

#### Scenario: Lab-infra README opens as a doc
- **WHEN** a user browses the Labs section or clicks a `lab-infra/` reference
- **THEN** the corresponding `lab-infra/*/README.md` opens as an in-app doc page, the same way scc-500's terraform READMEs do
