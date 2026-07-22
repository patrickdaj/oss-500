## ADDED Requirements

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
