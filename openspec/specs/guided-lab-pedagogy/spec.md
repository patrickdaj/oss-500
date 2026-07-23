# guided-lab-pedagogy Specification

## Purpose

OSS-500 labs must teach by having the learner build the control, not by handing over the finished artifact. This capability defines the standard lab shape — challenge → guided build → verify → reference solution — that requires the learner to produce the manifest, policy, command, query, or attack themselves and reach the prove-it observable, backed by a preserved, clearly-marked reference solution. It applies to all Domain 1–5 labs (the `d6-*` labs are the exemplar) and preserves every objective id, mapping, observable, and tracker entry unchanged.
## Requirements
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

### Requirement: A lab discloses whether its observable is host-validated
A lab whose prove-it observable has not been run end-to-end on a real host by the author SHALL carry a **host-pending** validation-status note near its Verification section, naming the specific step that is unvalidated and what surrounding logic *was* verified. The course SHALL also carry a course-level validation-status disclosure so a learner knows, up front, that some observables await an author host-run and that a step which does not behave as written is a finding to report, not a personal failing.

#### Scenario: A host-pending observable is marked
- **WHEN** a lab's prove-it observable has not been validated end-to-end on a host
- **THEN** the lab shows a "Validation status — host-pending" note naming the exact deferred step (e.g. the SPIRE chart bring-up, the NeMo rails + model round-trip) and what was verified, so the learner can tell a freshly-built step from a shaken-out one

#### Scenario: The course discloses validation status up front
- **WHEN** a learner opens the lab catalog (`labs/README.md`)
- **THEN** a course-level note states that the curriculum is newly authored, that `lab-infra` is real and largely verified as far as a laptop allows, and that per-lab "Validation status" lines mark which observables are still host-pending

#### Scenario: Marking is honest, not blanket
- **WHEN** the validation status of a lab is unknown or has been confirmed on a host
- **THEN** the lab is not falsely marked as validated; a positive "host-validated" marker is applied only to observables actually run on a host, and absence of a marker never asserts validation

