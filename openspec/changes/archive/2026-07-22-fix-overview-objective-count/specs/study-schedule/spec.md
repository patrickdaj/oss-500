## ADDED Requirements

### Requirement: Overview aggregate figures match source data
The plan overview under `plan/` SHALL state an objective total that equals the number of objective entries defined in `assessment/data/tracker.yaml` (summed across all domains `d1`–`d6`), so the overview never contradicts its cited source of truth.

#### Scenario: Objective total matches the tracker
- **WHEN** a reader compares the objective total stated in `plan/overview.md` against the count of objectives in `assessment/data/tracker.yaml`
- **THEN** the two figures are equal (currently 94)

#### Scenario: Adding tracker objectives keeps the overview in sync
- **WHEN** objectives are added to or removed from `assessment/data/tracker.yaml`
- **THEN** the objective total in `plan/overview.md` is updated to the new count so the stated figure still matches the source data
