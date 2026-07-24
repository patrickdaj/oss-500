## ADDED Requirements

### Requirement: Admission/runtime demos run in a non-restricted demo namespace
Namespaces used to demonstrate an admission-webhook or runtime-detection control SHALL NOT be labeled `pod-security.kubernetes.io/enforce: restricted`, because built-in PodSecurity admission runs before validating/mutating webhooks and would reject a non-compliant demo pod itself — pre-empting the control the lab exists to prove. `lab-infra/` SHALL provide a dedicated demo namespace (e.g. `gov-demo` / `runtime-demo`) carrying the standard `owner`/`oss500` labels for cleanup, and the four affected demos SHALL target it rather than `oss500-apps`.

#### Scenario: Demo namespace does not enforce restricted PSS
- **WHEN** a reader inspects the namespace used by the D1 governance, D3 pod-security, D3 runtime-detection, and D3 supply-chain demos in `lab-infra/shared/namespaces.yaml`
- **THEN** that namespace has no `pod-security.kubernetes.io/enforce: restricted` label, so a bare `kubectl run`/`kubectl create` demo pod reaches the webhook/runtime control instead of being rejected by built-in PSA

#### Scenario: Demo namespace is still labeled for cleanup
- **WHEN** the demo namespace is created
- **THEN** it carries the standard `owner`/`oss500` labels so a learner can identify and tear down all lab resources

### Requirement: Restricted-compliant victim manifests where a successful root read is the observable
Where a lab's observable depends on a *successful* privileged file read (e.g. Falco's `Read sensitive file untrusted` rule, which needs a completed `open`), `lab-infra/` SHALL ship a victim/target manifest that can actually perform that read, rather than one forced non-root by `restricted` PSS (which fails with EACCES before a descriptor exists).

#### Scenario: Runtime-detection victim can perform the sensitive read
- **WHEN** the D3 runtime-detection victim pod runs `cat /etc/shadow`
- **THEN** the read succeeds and Falco fires its sensitive-file rule after the fact, rather than the read failing at EACCES so no event is generated
