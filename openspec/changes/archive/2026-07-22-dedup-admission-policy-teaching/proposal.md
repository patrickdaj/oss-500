## Why

Admission policy-engine mechanics are currently taught **twice, independently**. `domains/1-identity-governance/governance.md` teaches the OPA Gatekeeper and Kyverno engines in full — the two-object model, `validationFailureAction: Enforce` vs `Audit`, `background`/audit scanning, webhook `failurePolicy` fail-open vs fail-closed, `kube-system` exemption, and the "Azure Policy for AKS *is* Gatekeeper" anchor. Then `domains/3-compute-ai/pod-security.md`, in its `pod-admission` section ("Enforce workload security at admission time"), re-teaches the *same* engine internals from scratch: it re-explains Kyverno-vs-Gatekeeper, `Enforce`/`Audit`, `failurePolicy` `Fail`/`Ignore` (fail-closed/open), exempting `kube-system`/the engine namespace, and repeats the identical "Azure Policy for AKS *is* Gatekeeper" anchor — and even ships a near-duplicate `disallow-privileged` ClusterPolicy YAML.

This is redundant maintenance surface and a divergence risk: two notes explaining the same mechanic will drift (already the `failurePolicy` framing differs slightly between them). The learner also can't tell which note is authoritative. Cross-cutting control mechanics should be single-sourced.

The genuinely pod-specific value in `pod-security.md`'s `pod-admission` section — the **PSA-vs-policy-engine boundary** (namespace profiles vs custom/per-workload rules), and **mutation-runs-before-validation to auto-harden bare pods so they pass PSA** — is not taught in `governance.md` and must be preserved.

## What Changes

- Establish a **single-sourcing convention** for cross-cutting control mechanics as a new `oss-curriculum` requirement: shared mechanics are taught in one canonical note and cross-linked, not re-derived per domain.
- Designate `governance.md` (objectives `gov-gatekeeper`, `gov-kyverno`) as the **canonical source** for admission policy-engine internals.
- **Trim** `pod-security.md`'s `pod-admission` section to the pod-specific delta only (PSA-vs-engine boundary; mutation-before-validation auto-hardening) and **cross-link** `governance.md` for the engine mechanics it currently re-derives.

## Capabilities

### Modified Capabilities
- `oss-curriculum`: ADD a requirement that cross-cutting control mechanics are single-sourced in one canonical note and cross-linked from other notes, which teach only their domain-specific delta. (No existing requirement is modified.)

> **Out of scope / follow-up:** the assessment quizzes carry the same overlap — `quiz-1` q1-25 (`gov-kyverno`) and q1-28 (`gov-gatekeeper`, `gov-kyverno`) test engine mechanics also probed by `quiz-3` q3-05 and q3-06 (`pod-admission`). De-duplicating or re-scoping those questions belongs to the `assessment-tracking` capability and is **not** addressed here; track as a follow-up change.

## Impact

- `domains/3-compute-ai/pod-security.md` — `pod-admission` section trimmed to the pod-specific delta; a cross-link to `governance.md` added for engine internals; the duplicated `disallow-privileged` YAML and re-taught `Enforce`/`Audit`/`failurePolicy`/`kube-system`/Azure-Policy-anchor prose removed (retain only what serves the pod delta).
- `domains/1-identity-governance/governance.md` — unchanged (already canonical); no content added or removed.
- `openspec/specs/oss-curriculum/spec.md` — gains one ADDED requirement (via delta).
- No change to objective ids, tracker, labs, or quizzes.
