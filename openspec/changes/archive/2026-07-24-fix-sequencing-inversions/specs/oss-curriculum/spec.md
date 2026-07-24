## ADDED Requirements

### Requirement: OTel span vocabulary is bridged before it is used in Domain 3

The `ai-observability` section of `domains/3-compute-ai/ai-security.md` reasons over OpenTelemetry spans and `gen_ai.*` attributes (including a `start_as_current_span` snippet) a full domain before `domains/4-posture-monitoring/observability.md` `obs-traces` defines span, trace, and `traceparent`. The curriculum SHALL NOT require a learner to reason over OTel span concepts before they are defined: either `ai-observability` SHALL carry a short inline span primer (span, trace, `traceparent`, `gen_ai.*` attributes) sufficient to read the section standalone, or the OTel-concepts slice of `obs-traces` SHALL be sequenced ahead of Domain 3 and cross-linked from `ai-observability`.

#### Scenario: A Domain 3 reader can parse the span snippet from Domain 3 material

- **WHEN** a learner new to observability reads `ai-observability` and reaches the `start_as_current_span` / `gen_ai.*` content
- **THEN** span, trace, `traceparent`, and the `gen_ai.*` attribute convention are defined at that point (inline or via a slice sequenced ahead of Domain 3), so the learner does not have to jump forward to Domain 4's `obs-traces` to understand what a span is

### Requirement: gov-compliance answers its own D1 quiz without a forward jump

`domains/1-identity-governance/governance.md` `gov-compliance` currently punts all Kubescape-scoring mechanics forward to `domains/4-posture-monitoring/vulnerability-posture.md` (`vuln-compliance`), which the learner reaches weeks later, leaving a D1 quiz on how the score is computed unanswerable from D1 material. `gov-compliance` SHALL inline the minimum scoring facts a D1 quiz needs — what `kubescape scan framework` produces, that the result is a compliance-percentage / secure-score analog, and the "score is not a formal certification" caveat — while retaining a forward cross-link to `vuln-compliance` for the full mechanics. `vuln-compliance` SHALL remain the canonical teacher of the scoring mechanics; the inline facts are the D1-answerable minimum, not a re-teaching.

#### Scenario: A D1 learner can answer a scoring question from D1 material

- **WHEN** a D1 learner reads `gov-compliance` and is quizzed on how the Kubescape compliance score is produced
- **THEN** the two or three facts needed to answer (framework scan → compliance %/secure-score analog, not a formal certification) are present inline in `gov-compliance`, with a cross-link forward to `vuln-compliance` for the full mechanics — so the forward reference enriches rather than blocks

#### Scenario: Canonical single-sourcing is preserved

- **WHEN** a reviewer compares the inlined `gov-compliance` facts against `vuln-compliance`
- **THEN** `vuln-compliance` remains the canonical location for the full scoring mechanics and `gov-compliance` restates only the D1-answerable minimum plus the cross-link, so the shared mechanic is not duplicated in full

### Requirement: The SPIRE walkthrough-to-operate transition is explicitly signposted

D1 `wi-spiffe` is walkthrough-only (no SPIRE server runs) and D6 `d6-identity` is the first and only place a live SPIRE server is operated. The D6 `d6-identity` intro SHALL state plainly that D1 gave the learner no live SPIRE muscle memory — this is the first and only hands-on SPIRE in the course — and SHALL lean on the SVID≈short-lived-certificate analogy as the bridge from the learner's PKI background.

#### Scenario: The D6 intro names the transition and offers the analogy

- **WHEN** a learner reaches `d6-identity` and stands up a live SPIRE server for the first time
- **THEN** the intro states plainly that D1 `wi-spiffe` was walkthrough-only with no prior live SPIRE, and offers the SVID≈short-lived-cert analogy as the anchor, so the learner is not surprised to be operating a tool he has only read about
