# Tasks — fix-sequencing-inversions

## 1. OTel span primer before D3 (4.1)

- [x] 1.1 Decide the approach: a five-line inline span primer in `ai-security.md` `ai-observability`, or moving the OTel-concepts slice of `observability.md` `obs-traces` ahead of Domain 3. (Inline primer is the lower-churn option.)
- [x] 1.2 Ensure span, trace, `traceparent`, and the `gen_ai.*` attribute convention are defined at the point `ai-observability` first uses them, so the section reads standalone; cross-link `obs-traces` for the full treatment.

## 2. Inline minimum scoring facts in gov-compliance (4.2)

- [x] 2.1 Inline into `governance.md` `gov-compliance` the D1-answerable facts: `kubescape scan framework` produces a compliance %/secure-score analog, and the "not a formal certification" caveat.
- [x] 2.2 Keep `vulnerability-posture.md` `vuln-compliance` as the canonical full-mechanics teacher; replace the bare forward punt with a cross-link that reads as enrichment, not a prerequisite.

## 3. Signpost the SPIRE transition (4.5)

- [x] 3.1 In the `d6-identity` intro, state plainly that D1 `wi-spiffe` was walkthrough-only (no live SPIRE) and this is the first and only hands-on SPIRE in the course.
- [x] 3.2 Lean on the SVID≈short-lived-certificate analogy as the bridge from the learner's PKI background.

## 4. Validation

- [x] 4.1 Run `openspec validate fix-sequencing-inversions --type change --strict` and fix until it passes.
