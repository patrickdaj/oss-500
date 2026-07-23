## ADDED Requirements

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
