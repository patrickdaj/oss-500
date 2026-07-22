## ADDED Requirements

### Requirement: A lab presents a challenge and a guided build before any full solution
Every lab in Domains 1–5 SHALL present, before disclosing a complete solution, (a) a **challenge** stating what the learner must achieve and the observable to reach, and (b) a **guided build** — hints, checkpoints, partial scaffolding, and explicit "your turn" prompts — that requires the learner to produce the artifact (manifest, policy, command, query, or attack) themselves. The finished artifact SHALL NOT appear inline in the build steps.

#### Scenario: A lab guides rather than hands over
- **WHEN** a retrofitted lab is read top to bottom
- **THEN** the learner encounters the challenge and guided build first, is prompted to write the artifact themselves, and does not find the complete solution inline in the step-by-step flow

#### Scenario: The strong "why" is retained
- **WHEN** the guided-build section is read
- **THEN** the explanations of why each step matters (the course's existing narration) are preserved, only the finished artifact is withheld

### Requirement: The full solution is preserved in a marked reference section or lab-infra
Every lab SHALL retain its complete solution, relocated to a clearly-marked **Reference solution** section at the end of the lab (labelled "build it first, check after") or, when the artifact is a deployable manifest/policy, a pointer to the `lab-infra/<component>/` file that holds it. No solution content SHALL be deleted — only relocated and marked.

#### Scenario: The learner can check their work
- **WHEN** the learner has attempted the build and wants to verify their artifact
- **THEN** a Reference solution section (or a lab-infra pointer) provides the complete, correct solution to compare against

#### Scenario: Nothing is lost
- **WHEN** a retrofitted lab is compared to its original
- **THEN** every command/manifest/policy that was inline still exists in the repo (in the Reference solution section or a lab-infra file), unchanged in substance

### Requirement: The prove-it observable is retained
Every lab SHALL keep its concrete verification observable — the denied request, fired rule, blocked connection, refused token, or equivalent — as the definition of "done." The guided build SHALL lead to that observable, and the reference solution is what the learner compares against after reaching it.

#### Scenario: Verification survives the retrofit
- **WHEN** a retrofitted lab's Verification section is read
- **THEN** it still names the same concrete observable the original required, and the learner confirms the control holds by reaching it

### Requirement: The lab pedagogy is documented as the course convention
`labs/README.md` SHALL document the *challenge → guided build → verify → reference solution* template as the standard for how labs teach, citing the `d6-*` labs as the exemplar, so future labs inherit the pattern.

#### Scenario: The convention is discoverable
- **WHEN** a contributor reads `labs/README.md`
- **THEN** the guided-build lab template is described and pointed to a concrete exemplar

### Requirement: Objectives, mappings, and tracker are unchanged
The retrofit SHALL NOT change any lab's objective ids, Objectives-covered table, SC-500 correspondence/Standards line, or the course `tracker.yaml`. It is a change to how a lab teaches, not what it covers.

#### Scenario: Coverage is invariant
- **WHEN** the tracker and each lab's Objectives table are compared before and after the change
- **THEN** the objective ids, SC-500 mappings, and tracker entries are identical
