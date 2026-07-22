## ADDED Requirements

### Requirement: Cross-cutting control mechanics are single-sourced and cross-linked
When a control mechanic applies across more than one SC-500 domain (e.g., admission policy-engine internals, secret injection, image signing), the curriculum SHALL teach that mechanic in full in exactly one **canonical** note — the note owning the objective for which the mechanic is the primary subject — and every other note that relies on it SHALL cross-link the canonical note rather than re-deriving the mechanic. A non-canonical note SHALL restate only its own domain-specific delta (how the shared mechanic is *applied* in that domain), not the shared mechanic itself, so a shared mechanic has a single source of truth and cannot drift between notes.

#### Scenario: Admission policy-engine mechanics live only in governance.md
- **WHEN** a reader opens `domains/3-compute-ai/pod-security.md` and reaches the `pod-admission` section
- **THEN** the engine internals (Kyverno/Gatekeeper authoring models, `Enforce` vs `Audit`, webhook `failurePolicy` fail-open/closed, `kube-system` exemption, the "Azure Policy for AKS is Gatekeeper" anchor) are cross-linked to the canonical `gov-gatekeeper`/`gov-kyverno` sections of `domains/1-identity-governance/governance.md` and not re-taught, while the section still teaches inline its pod-specific delta — the PSA-vs-policy-engine boundary and mutation-runs-before-validation to auto-harden pods

#### Scenario: A duplicated mechanic is detected as a defect
- **WHEN** a reviewer finds the same control mechanic taught in full in two different `domains/` notes
- **THEN** it is treated as a single-sourcing violation: one note is designated canonical and the other is reduced to its domain-specific delta plus a cross-link to the canonical note
