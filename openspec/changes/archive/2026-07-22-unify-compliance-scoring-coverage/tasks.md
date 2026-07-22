## 1. Establish the canonical teaching location (`vuln-compliance`)

- [x] 1.1 In `domains/4-posture-monitoring/vulnerability-posture.md`, confirm the `vuln-compliance` section is the single, complete source of truth for Kubescape framework compliance-scoring: framework scans (`kubescape scan framework nsa/cis/mitre`), the severity-weighted compliance %/secure-score, report/output formats (PDF/HTML/JSON/SARIF/JUnit), the trend-to-improve loop, and the "technical-controls score is NOT a formal certification" caveat. Add a short anchor/marker (stable heading) that other notes can cross-reference.
- [x] 1.2 Do not otherwise expand or re-scope `vuln-compliance`; it already carries the fuller treatment.

## 2. Reframe the non-canonical section (`gov-compliance`) to defer by reference

- [x] 2.1 In `domains/1-identity-governance/governance.md`, rewrite the `gov-compliance` ("Evaluate compliance against frameworks and baselines") section so it frames Kubescape compliance scoring as an **application in the governance context**: it is the detective/measure half that pairs with preventive admission enforcement (Gatekeeper/Kyverno `deny`/`Enforce`) and feeds the `gov-iac` shift-left `--compliance-threshold` gate.
- [x] 2.2 Remove the duplicated *mechanics* from `gov-compliance`: the enumerated framework list, how the score is computed/severity-weighted, the report formats, and the score-≠-certification caveat. Replace them with a one-to-two-sentence statement of the skill plus an explicit cross-reference to the canonical `vuln-compliance` section in `domains/4-posture-monitoring/vulnerability-posture.md` for the mechanics.
- [x] 2.3 Keep the `gov-compliance` heading, metadata line, objective id, and its curated resources; keep the governance-specific SC-500 mapping. This is a reframe, not a deletion.
- [x] 2.4 Update the `governance.md` summary-table row for `gov-compliance` so it reflects the governance-application framing (measure-then-enforce) rather than re-stating the scoring mechanic.

## 3. Keep both tracker objectives, differentiated

- [x] 3.1 In `assessment/data/tracker.yaml`, keep both `gov-compliance` and `vuln-compliance` rows (do not remove either id).
- [x] 3.2 Differentiate their `text` descriptions so the two lenses are explicit and non-overlapping: `gov-compliance` = governance/policy application (measure the estate against a framework as the detective half of governance; apply Kubescape scoring, then enforce); `vuln-compliance` = canonical scoring/reporting (produce the compliance %/secure-score and audit report). Keep the `oss`/`sc500` mappings accurate for both.

## 4. Verify

- [x] 4.1 Confirm the `gov-compliance` → `vuln-compliance` cross-reference resolves and that no scoring mechanics remain duplicated across the two sections.
- [x] 4.2 Run `npm run lint:links` and confirm the new cross-reference (and all links) resolve.
- [x] 4.3 Run `openspec validate unify-compliance-scoring-coverage --strict` and confirm it passes.
