## Why

Two objectives teach the **same skill with the same tool** as if it were new material in each place:

- `gov-compliance` (Domain 1, `domains/1-identity-governance/governance.md` → "Evaluate compliance against frameworks and baselines") — *"Kubescape does this open-source: it evaluates the live cluster … against built-in frameworks — NSA-CISA, MITRE ATT&CK, CIS … reporting per-control pass/fail, a compliance score, and remediation."*
- `vuln-compliance` (Domain 4, `domains/4-posture-monitoring/vulnerability-posture.md` → "Produce compliance and secure-score style reports") — *"Kubescape scans against named frameworks: NSA-CISA … MITRE ATT&CK … CIS … yields a compliance score (%), a per-control breakdown, and a risk/priority score."*

Both teach the identical mechanic — `kubescape scan framework <nsa|cis|mitre>` → compliance %/secure-score — map it to the **same SC-500 control** (Defender secure score / regulatory compliance), and end on the **same caveat** (a passing score is technical-control coverage, *not* a formal certification). The `tracker.yaml` entries confirm the collision: both carry `oss: Kubescape … frameworks` and `sc500: … secure score / regulatory compliance`. The duplication even leaked into the question bank as near-identical items **q1-26** (`gov-compliance`) and **q4-29** (`vuln-compliance`), both probing "score ≠ certification."

Teaching the same tool-and-skill twice wastes learner time, invites the two copies to drift, and blurs *why* the objective exists in each domain. The curriculum has no stated rule that a shared tool-and-skill is taught once and applied by reference — so nothing prevents the next such overlap.

## What Changes

- **Add a curriculum requirement**: objectives that share a single tool *and* the same underlying skill are **taught once** in one canonical location and **applied by reference** elsewhere, where the second location frames the skill in its own domain context rather than re-teaching the mechanics.
- **Designate `vuln-compliance` (Domain 4, posture-monitoring) as the canonical teaching location** for Kubescape framework compliance-scoring — the mechanics of running framework scans, computing a compliance %/secure-score, output/report formats, and the score-≠-certification caveat. (Justification in `design.md`.)
- **Reframe `gov-compliance` (Domain 1) as an application** in the governance context: it *uses* Kubescape scoring to answer the governance question — measure the estate against a framework *before/alongside* admission enforcement (Gatekeeper/Kyverno) and gate IaC pre-deploy (`gov-iac`) — and **defers the scoring mechanics and the certification caveat** to `vuln-compliance` by reference, rather than re-explaining them.
- **Both tracker objectives are kept**, with their descriptions differentiated so coverage is preserved and the governance-vs-posture lens is explicit.
- The **near-duplicate quiz pair q1-26 ↔ q4-29** is out of scope here and is handled by the separate `dedup-quiz-question-intent` change; this proposal only removes the duplicated *teaching* in the notes.

## Capabilities

### Modified Capabilities
- `oss-curriculum`: Add a requirement that objectives sharing a tool-and-skill are taught once (canonical) and applied by reference elsewhere. No existing shared requirements are modified; this is a new requirement in the delta.

## Impact

- **Content**: `domains/4-posture-monitoring/vulnerability-posture.md` (`vuln-compliance`) becomes the single source of truth for Kubescape compliance-scoring mechanics (light touch — it already carries the fuller treatment). `domains/1-identity-governance/governance.md` (`gov-compliance`) is reframed to defer the mechanics and keep only the governance-context application, with an explicit cross-reference.
- **Tracker**: `assessment/data/tracker.yaml` — both `gov-compliance` and `vuln-compliance` remain; their `text` descriptions are differentiated (governance/policy lens vs posture-reporting lens). No objective ids are removed.
- **Assessments**: quiz items are untouched by this change (q1-26/q4-29 handled by `dedup-quiz-question-intent`).
- **Verification**: `npm run lint:links` (cross-references resolve) and `openspec validate unify-compliance-scoring-coverage --strict` must pass.
