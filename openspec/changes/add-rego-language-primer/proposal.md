# Teach Rego as a language before the first lab asks the learner to author it

## Why

Rego is the highest-frequency "used-before-it's-taught" gap in the course. The curriculum has the learner *author or reason about* a Rego policy in six places — D1 `governance` lab Part B (write a violation rule), D3 `ai-governance` (`opa eval`), and D6 ×3 (`tool-authz`, `action-class`, and the guardrail objective) — but no note ever teaches Rego *as a language*. Every one of these hands the learner a blank-page policy and outsources the syntax to the external OPA docs.

For this persona the gap is real, not softened: strong Python fluency does **not** transfer to Rego's declarative, partial-set / rule-based evaluation model. The result is the exact outcome the audit is trying to prevent — intermediate-and-reference-dependent instead of expert-and-standalone — and it recurs across three domains, so a single primer pays off repeatedly.

## What Changes

- Add a **Rego language primer** to the curriculum at the point of first need — the note whose lab first requires authoring Rego (D1 `governance`) — covering the declarative evaluation model, rules and their bodies, partial sets/objects (`deny[msg] { … }`), `input` document navigation, and running a policy with `opa eval`.
- Cross-link the primer from every later Rego-using objective (`ai-governance`, `tool-authz`, `action-class`, and the D6 guardrail objective) so its teaching is single-sourced, not re-derived per domain.
- Mark the primer as concept-new for the networking persona (Python does not transfer), the way the AI notes are flagged concept-new.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `oss-curriculum` — adds a requirement that a language/policy framework the labs require the learner to *author* is taught as a language before its first authoring lab, applied to Rego specifically.

## Impact

- Affected specs: `oss-curriculum` (one ADDED requirement).
- Affected content (at implementation time): the D1 `governance` note (new primer section) and cross-links from `ai-governance`, `tool-authz`, `action-class`, and the D6 guardrail objective.
- Unblocks first-time Rego authoring in `governance` Part B and removes the silent dependency on external OPA docs across three domains.
