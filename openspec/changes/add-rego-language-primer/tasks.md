# Tasks — add-rego-language-primer

## 1. Author the primer

- [ ] 1.1 Add a Rego language primer to the D1 `governance` note (the first note whose lab authors Rego), covering: the declarative evaluation model; rules and rule bodies; partial-set/partial-object collection rules (`deny[msg] { … }`); navigating the `input` document; and running a policy with `opa eval`.
- [ ] 1.2 Flag the primer concept-new for the networking persona, stating that Python fluency does not transfer to Rego's declarative/partial-set model.
- [ ] 1.3 Ensure the primer is sufficient to author the `governance` lab Part B violation rule from course materials alone.

## 2. Cross-link the reuse sites

- [ ] 2.1 Cross-link the primer from `ai-governance` (`opa eval`).
- [ ] 2.2 Cross-link the primer from D6 `tool-authz`, `action-class`, and the guardrail objective.
- [ ] 2.3 Confirm no reuse site re-teaches the Rego language (single-sourcing).

## 3. Validation

- [ ] 3.1 Run `openspec validate add-rego-language-primer --type change --strict` and confirm it passes.
