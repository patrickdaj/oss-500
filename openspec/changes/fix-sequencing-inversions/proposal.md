# Fix three teaching-sequence inversions

## Why

The curriculum's concept ordering is sound, but three places demand or reference a concept before the note that defines it — each costing this persona (new to cloud/K8s/AI) hours of backtracking (audit Part 4 items 4.1, 4.2, 4.5, lines 114–116 and 122; suggested change line 164). All three are cheap, additive, and independently verifiable:

- **OTel used in D3, taught in D4 (4.1).** `domains/3-compute-ai/ai-security.md` `ai-observability` reasons over spans and `gen_ai.*` attributes — with a Python `start_as_current_span` snippet — a full domain before `domains/4-posture-monitoring/observability.md` `obs-traces` defines span, trace, and `traceparent`. The D3 learner meets the vocabulary with nothing to anchor it.
- **`gov-compliance` forward-refs a Phase-4 note (4.2).** `domains/1-identity-governance/governance.md` `gov-compliance` punts *all* Kubescape-scoring mechanics to `domains/4-posture-monitoring/vulnerability-posture.md` ("read them there") — a note reached weeks later — so a D1 quiz on how the score is computed is unanswerable from D1 material.
- **SPIRE walkthrough→operate transition unsignposted (4.5).** D1 `wi-spiffe` is walkthrough-only (no server runs); D6 `d6-identity` is the first and only live SPIRE. The D6 intro is honest but should state plainly there was no prior SPIRE muscle memory and lean on the SVID≈short-lived-cert analogy.

## What Changes

- **4.1 — bridge OTel before D3.** Add a five-line span primer (span/trace/`traceparent`/`gen_ai.*`) to the `ai-observability` section of `ai-security.md`, OR move the OTel-concepts slice of `observability.md` `obs-traces` ahead of D3. Either way, D3 no longer reasons over spans the learner has never had defined.
- **4.2 — inline the minimum scoring facts in `gov-compliance`.** Keep `vulnerability-posture.md` (`vuln-compliance`) as the canonical teacher of the scoring mechanics, but inline into `gov-compliance` the two or three facts a D1 quiz needs (what `kubescape scan framework` produces, that the output is a compliance %/secure-score-analog, and the "not a formal certification" caveat), with a cross-link forward for the full mechanics — so the forward-reference enriches rather than blocks.
- **4.5 — signpost the SPIRE transition.** In the D6 `d6-identity` intro, state plainly that D1 `wi-spiffe` gave no live SPIRE muscle memory (this is the first and only place a SPIRE server runs) and lean on the SVID≈short-lived-cert analogy as the bridge.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `oss-curriculum` — adds three requirements (one per distinct inversion) that a concept used or quizzed in an earlier note is either defined or minimally bridged at the point of first need, and that a walkthrough→operate transition is explicitly signposted.

## Impact

- Affected specs: `oss-curriculum` (three ADDED requirements — one per fix, each independently verifiable).
- Affected content (at implementation time): `domains/3-compute-ai/ai-security.md` `ai-observability` (or an OTel slice of `domains/4-posture-monitoring/observability.md`); `domains/1-identity-governance/governance.md` `gov-compliance`; the D6 `d6-identity` intro.
- Does not remove the canonical single-sourcing already required for Kubescape scoring — the 4.2 fix inlines only the minimum D1-answerable facts and keeps the forward cross-link.
