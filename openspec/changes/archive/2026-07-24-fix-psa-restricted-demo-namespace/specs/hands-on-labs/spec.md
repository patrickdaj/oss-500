## ADDED Requirements

### Requirement: Admission/runtime labs surface the observable from the control under test
A lab demonstrating an admission-webhook or runtime-detection control SHALL produce its positive/observable result from *that* control, not from built-in PodSecurity admission. The lab SHALL run its demo pods in a non-`restricted` demo namespace and SHALL include one sentence on admission-controller ordering (built-in PSA evaluates before validating/mutating webhooks) explaining why the demo namespace is unrestricted.

#### Scenario: Kyverno is the enforcement point the learner observes
- **WHEN** the D1 governance Part A privileged demo pod or the D3 pod-security Part C `evil` pod is applied
- **THEN** admission or rejection is decided by Kyverno (including the "flip to `Audit` → pod admitted → PolicyReport violation" and "rejected by Kyverno with your custom message" observables), rather than the pod being pre-empted by built-in PSS

#### Scenario: Supply-chain "signed image admitted" case is reachable
- **WHEN** the D3 supply-chain Part D signed image is applied to the demo namespace
- **THEN** it is admitted (Kyverno verification passes and no `restricted` PSS check rejects it afterward), so the positive test is observable

#### Scenario: Admission-ordering reason is taught
- **WHEN** a learner reads any of the four affected labs
- **THEN** it states that built-in PSA runs before webhooks and is why the demo namespace is not `restricted`
