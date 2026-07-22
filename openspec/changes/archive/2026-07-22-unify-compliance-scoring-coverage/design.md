## Context

OSS-500 organizes study notes by SC-500 domain, one objective per heading, joined to `assessment/data/tracker.yaml` by stable objective ids. Kubescape appears legitimately in several objectives (`gov-compliance`, `gov-iac`, `vuln-cluster`, `vuln-cis`, `vuln-remediate`, `vuln-compliance`) because it is a genuinely cross-cutting tool. That is fine when each objective uses a *different facet* of the tool — configuration/posture scanning (`vuln-cluster`), CIS node auditing (`vuln-cis`), CVE+config prioritization (`vuln-remediate`), shift-left IaC scanning (`gov-iac`).

The problem is the two objectives that use the **same facet** — framework compliance scoring — and teach it from scratch in both:

- `gov-compliance` — `governance.md`, "Evaluate compliance against frameworks and baselines": `kubescape scan framework nsa/cis/mitre` → per-control pass/fail, severity-weighted compliance score, "passing compliance score is not a certification."
- `vuln-compliance` — `vulnerability-posture.md`, "Produce compliance and secure-score style reports": the same framework scans → compliance %, per-control breakdown, risk/priority score, report formats (PDF/HTML/JSON/SARIF/JUnit), "compliant means technical controls pass … not the same as being certified."

Both map to the same SC-500 control (Defender secure score / regulatory compliance), and `tracker.yaml` records the same `oss`/`sc500` values for both. The duplication also surfaced as near-duplicate quiz items q1-26 and q4-29. The `governance.md` note even self-acknowledges the overlap ("in Domain 4 (`vuln-*`) Kubescape reappears for posture management; here the lens is *governance/compliance frameworks*") — but still re-teaches the mechanics rather than deferring them.

## Goals / Non-Goals

**Goals:**
- Teach Kubescape framework compliance-scoring **once**, in one canonical location.
- Keep the second objective meaningful by framing it as an **application** of that skill in its own domain context.
- Preserve tracker coverage: both objectives remain, differentiated.
- Establish a reusable curriculum rule so future shared-tool overlaps are prevented, not just this one fixed.

**Non-Goals:**
- Not deleting either objective from the tracker or removing any heading from the notes.
- Not touching the quiz duplication (q1-26/q4-29) — that is `dedup-quiz-question-intent`.
- Not changing the *other* Kubescape objectives (`vuln-cluster`, `vuln-cis`, `vuln-remediate`, `gov-iac`) — they use distinct facets and are not duplicates.
- Not re-teaching or re-scoping SC-500 mappings beyond removing the duplicated explanation.

## Decisions

**D1 — `vuln-compliance` (Domain 4, posture-monitoring) is the canonical teaching location for Kubescape compliance-scoring mechanics.**

Rationale:
- The objective *is literally* about producing the score and the report ("Produce compliance and secure-score style reports") — scoring is its subject, not a supporting detail. Compliance-scoring is fundamentally a **posture-management/reporting** activity: assess the estate, express it as a trendable secure-score, report it to an auditor.
- The Domain 4 note already carries the **richer, more complete** treatment: output/report formats (PDF/HTML/JSON/SARIF/JUnit), the risk/priority score, the NIST 800-137 ISCM continuous-monitoring framing, and the trend-to-improve loop. It sits alongside its natural neighbors — `vuln-cluster` (posture), `vuln-cis` (kube-bench), `vuln-remediate` (Trivy) — so a reader learns scanning → scoring → reporting → remediation in one place.
- `gov-compliance`'s home domain is **governance**, whose spine is *policy* — admission enforcement (Gatekeeper/Kyverno) and controls-as-code (`gov-iac`). Scoring there is a means to a governance end (measure before you enforce), not the point of the domain.

**D2 — `gov-compliance` is reframed as an application, not deleted.**

In `governance.md`, `gov-compliance` keeps its heading and its governance-specific value: compliance scanning is the **detective/measure** half of the governance loop that pairs with the **preventive/enforce** half (Gatekeeper/Kyverno `deny`/`Enforce`) and feeds the shift-left IaC gate (`gov-iac` `--compliance-threshold`). It states the skill in one or two sentences and **defers to `vuln-compliance` by an explicit cross-reference** for the mechanics: the framework list, how the score is computed/severity-weighted, the report formats, and the score-≠-certification caveat. It does not re-explain them.

**D3 — Not deleting either objective from the tracker; only removing duplicated teaching.**

Both `gov-compliance` and `vuln-compliance` remain rows in `tracker.yaml`. Their `text` descriptions are differentiated to make the two lenses explicit and non-overlapping — e.g. `gov-compliance` framed as "measure the estate against a framework as the detective half of governance (apply Kubescape scoring; enforce via policy)" and `vuln-compliance` as "produce the compliance %/secure-score and audit report (canonical scoring mechanics)." The `oss`/`sc500` mapping stays accurate for both; the differentiation is in emphasis (policy application vs scoring/reporting), not in fabricating a different tool.

**D4 — The canonical/apply-by-reference rule is added as a new curriculum requirement.**

Rather than a one-off fix, add a requirement to `oss-curriculum` that generalizes the pattern: when two objectives share the same tool *and* the same underlying skill, one is canonical and the other applies it by reference. This makes the fix checkable and prevents recurrence.

## Risks / Trade-offs

- **Risk: breaking tracker objective coverage.** If `gov-compliance` were thinned too far it could look like the governance domain lost a measured objective. → **Mitigation:** both objectives remain in `tracker.yaml` with differentiated descriptions; `gov-compliance` keeps a substantive governance-context section (measure-then-enforce, IaC gate) and a real SC-500 mapping — it is reframed, not gutted. Coverage of the SC-500 bullet in Domain 1 is preserved.
- **Risk: a learner reading `governance.md` in isolation misses the scoring mechanics.** → **Mitigation:** the deferral is an explicit, named cross-reference to `vuln-compliance` (not a silent omission), and the `lint:links` check confirms the cross-reference resolves.
- **Risk: cross-reference rot.** A link/anchor from `gov-compliance` to `vuln-compliance` could break later. → **Mitigation:** `npm run lint:links` is part of the task list and CI; the reference is by objective id / stable heading.
- **Trade-off: canonical-location choice is a judgment call.** One could argue governance is the "policy compliance" home. → We chose the posture-monitoring home because the *scoring/reporting mechanic* is the subject of `vuln-compliance` and the governance interest is genuinely the *application* (measure→enforce). The rule (D4) matters more than the specific pick; the pick is justified in D1.
