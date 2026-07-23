## ADDED Requirements

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
