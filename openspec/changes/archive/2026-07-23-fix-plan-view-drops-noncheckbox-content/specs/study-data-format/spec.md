## MODIFIED Requirements

### Requirement: Plan and reference conventions match study-hub parsing
Plan day-blocks SHALL use the `- [ ] **[Nh] <block>** — details` task-list convention that study-hub's plan parser reads into phases/days/blocks, and in-content references SHALL use resolvable shapes — repo doc paths (`plan/`, `domains/`, `labs/`, `assessment/` markdown), `lab-infra/` component paths, and tracker objective ids — so study-hub's resolver renders them as live links and backlinks without oss-500 shipping any linking code.

study-hub's plan parser SHALL additionally preserve any authored non-checkbox content under a `##` heading — numbered lists, prose paragraphs, and plain bullets — as raw markdown carried on the parsed group, and the plan section view SHALL render that content as markdown alongside the group's checkable blocks. The parsed plan route SHALL therefore render the same authored content as the raw doc route for a given plan file (it SHALL NOT be lossy). The "no blocks" / "rest day" placeholder SHALL appear only for a group that has neither checkbox blocks nor preserved non-checkbox content. Checkbox blocks remain interactive and their progress roll-up is unchanged; this behavior is additive.

#### Scenario: Plan blocks parse
- **WHEN** study-hub ingests a phase plan file
- **THEN** its day headings and `**[Nh]**` blocks parse into checkable plan blocks

#### Scenario: References resolve to live links
- **WHEN** a domain note or lab references an objective id or a `labs/`/`lab-infra/` path
- **THEN** study-hub's resolver renders it as an in-app link, and `lint:content` fails on any path-shaped reference that does not resolve

#### Scenario: Non-checkbox section content is preserved and rendered
- **WHEN** a plan file contains a `##` section whose body is authored as a numbered list, prose, or plain bullets rather than `- [ ]` checkboxes (for example the `## Self-check (pass before Phase 1)` list in `plan/phase0-fundamentals.md`)
- **THEN** the parser carries that content on the group and the plan section view renders it as markdown, so all items appear in the plan route

#### Scenario: Plan route matches the doc route
- **WHEN** the same plan file is viewed through the parsed plan route (`/plan/<file>`) and the raw doc route (`/doc/plan/<file>.md`)
- **THEN** every authored line present in the raw doc view is also present in the plan view — the plan view is not lossy

#### Scenario: Rest-day placeholder is not a false positive
- **WHEN** a group has no checkbox blocks but does carry authored non-checkbox content
- **THEN** the plan view renders that content and does NOT show the "no blocks / rest day" placeholder, which appears only when a group is genuinely empty
