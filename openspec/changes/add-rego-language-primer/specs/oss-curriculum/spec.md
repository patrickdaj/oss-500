## ADDED Requirements

### Requirement: Rego is taught as a language before the first lab authors it
The curriculum SHALL contain a Rego language primer, placed in (or cross-linked from) the note whose lab first requires the learner to author Rego — the D1 `governance` objective — that teaches Rego's declarative evaluation model, rules and rule bodies, partial-set/partial-object collection rules (e.g. `deny[msg] { … }`), navigation of the `input` document, and evaluating a policy with `opa eval`. The primer SHALL be sufficient for the learner to author the `governance` lab Part B violation rule from course materials alone, without reading the upstream OPA language reference first, and SHALL be flagged concept-new because Python fluency does not transfer to Rego's model. Every later objective that authors or evaluates Rego — `ai-governance`, `tool-authz`, `action-class`, and the D6 guardrail objective — SHALL cross-link this primer rather than re-teaching the language.

#### Scenario: The governance lab's first Rego rule is authorable from the note
- **WHEN** a learner reaches the D1 `governance` lab Part B and must author a violation rule
- **THEN** a linked Rego primer in course materials has already taught the declarative model, rule bodies, partial-set collection, `input` navigation, and `opa eval`, so the learner can write the rule without leaving the course for the OPA language reference

#### Scenario: Later Rego objectives reuse the single primer
- **WHEN** a learner reaches `ai-governance` (`opa eval`), `tool-authz`, `action-class`, or the D6 guardrail objective
- **THEN** each note cross-links the same Rego primer rather than re-deriving the language, so Rego is single-sourced across the three domains that use it

#### Scenario: The primer is flagged concept-new
- **WHEN** the networking-strong persona opens the Rego primer
- **THEN** it is flagged concept-new and states plainly that Python fluency does not transfer to Rego's declarative/partial-set evaluation model
