## Context

Two notes teach admission policy-engine mechanics independently:

- `domains/1-identity-governance/governance.md` — objectives `gov-gatekeeper` (Gatekeeper: ConstraintTemplate/Constraint two-object model, Rego, `enforcementAction`, audit loop) and `gov-kyverno` (Kyverno: `ClusterPolicy`, validate/mutate/generate/verifyImages, `validationFailureAction: Enforce` vs `Audit`, `background: true`, PolicyExceptions). It carries the full engine treatment, the webhook `failurePolicy` fail-open/closed trade-off, `kube-system`/control-plane exemption, and the "Azure Policy for AKS *is* Gatekeeper" anchor.
- `domains/3-compute-ai/pod-security.md` — objective `pod-admission` ("Enforce workload security at admission time") re-teaches the same engines: a duplicate `disallow-privileged` Kyverno `ClusterPolicy`, `Enforce`/`Audit`, `failurePolicy` `Fail`/`Ignore`, exempting `kube-system`/the engine's own namespace, and a second copy of the "Azure Policy for AKS *is* Gatekeeper" anchor.

The overlap is real and near-verbatim in places (the ClusterPolicy YAML, the `failurePolicy` gotcha, the Azure anchor). But `pod-security.md` also holds pod-specific content absent from `governance.md`: the **PSA-vs-policy-engine boundary** (PSA = three fixed profiles at namespace scope; engine = custom rules, per-workload exceptions, image/signature policy — layer, don't choose) and the **mutation-before-validation** mechanism used to auto-harden bare pods so they pass PSA. That delta is the reason the section exists.

## Goals / Non-Goals

**Goals:**
- Single-source admission policy-engine internals in `governance.md`.
- Reduce `pod-security.md`'s `pod-admission` section to the pod-specific delta plus a cross-link.
- Codify a general single-sourcing requirement in `oss-curriculum` so this pattern is enforced, not a one-off cleanup.

**Non-Goals:**
- **Do not touch `governance.md`'s canonical content.** It is already the fuller, correct treatment; this change does not add to or edit it.
- **Do not remove the pod-specific value** from `pod-security.md` — the PSA-vs-engine boundary and the mutation-before-validation auto-hardening insight stay.
- Do not re-scope or de-duplicate quiz questions (q1-25/q1-28 ↔ q3-05/q3-06) — that is `assessment-tracking` follow-up.
- Do not change objective ids, the tracker, or lab steps.

## Decisions

**D1 — `governance.md` is canonical, not `pod-security.md`.** The engine mechanics (two-object/`ClusterPolicy` models, Enforce/Audit, background scanning, `failurePolicy`, exemptions, the Azure-Policy-for-AKS anchor) are a **governance** concern that applies to *any* resource kind, not just pods — Gatekeeper/Kyverno gate namespaces, images, RBAC, network policy, and more. `governance.md` already teaches both engines in full as first-class objectives (`gov-gatekeeper`, `gov-kyverno`); `pod-security.md` reaches for them only as one *application* (hardening pods). The general mechanic belongs with the general objective; the pod note consumes it. Reversing this (making the pod note canonical) would force every other consumer of admission policy to link into a compute-domain note for cross-cutting mechanics — the wrong dependency direction.

**D2 — The pod note keeps only its delta and cross-links the rest.** After trimming, `pod-security.md`'s `pod-admission` section teaches: (a) *why* an engine is needed beyond PSA (the PSA-vs-engine boundary), and (b) the pod-relevant *use* of engine mutation — mutation runs before validation, so a mutate rule can auto-harden a bare pod into compliance before PSA judges it. For the engine internals themselves (authoring model, Enforce/Audit, failurePolicy, exemptions, Azure anchor) it links to `governance.md`'s `gov-gatekeeper`/`gov-kyverno` sections rather than restating them.

**D3 — Carry the convention as an `oss-curriculum` requirement.** `oss-curriculum` is the archived, delta-able capability that governs the `domains/` study notes, so the single-sourcing rule is added there as a new requirement (ADDED, not modifying existing ones). Its scenario is grounded in this exact case so it is concrete, but the requirement text is general enough to cover any future cross-cutting mechanic taught in more than one domain.

## Risks / Trade-offs

- **Cross-link fragility.** A learner in Domain 3 must follow a link back to Domain 1 for engine details. → Mitigated by keeping the pod note self-contained *for the pod delta* (the reader still learns the PSA boundary and mutation-ordering inline) and linking out only for the reusable mechanics; the anchor targets stable objective headings.
- **Trimming could drop content that felt pod-specific but isn't duplicated.** → Task 2 is an explicit "verify no lost pod-specific content" gate: diff the removed prose against `governance.md` and confirm each removed sentence has an equivalent there; anything unique to pods is retained or folded into the delta.
- **Requirement too tied to this case.** → Requirement text is phrased generally (any shared control mechanic), with admission policy engines as the worked scenario, so it stays a real, reusable rule.
