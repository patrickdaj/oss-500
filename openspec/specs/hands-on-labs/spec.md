# hands-on-labs Specification

## Purpose

OSS-500 teaches SC-500 concepts by proving their open-source equivalents in runnable labs. This capability defines the lab catalog and lab format: every skills-outline subsection maps to at least one lab, each lab follows a standard structure with a concrete verification step, every lab names the SC-500 control it corresponds to, and topics impractical to run locally are covered by explicitly-marked walkthrough labs.
## Requirements
### Requirement: Lab catalog covers every objective subsection
The repo SHALL provide a lab catalog under `labs/` where every skills-outline subsection maps to at least one lab, with a catalog index (`labs/README.md`) presenting a table that maps each subsection (tracker id) to its lab(s), the lab type (hands-on / walkthrough), and the OSS component(s) it exercises.

#### Scenario: Catalog index maps objectives to labs
- **WHEN** a reader opens `labs/README.md`
- **THEN** they see a table mapping each skills-outline subsection to its lab(s), the lab type, and the OSS tool(s) used

#### Scenario: Full objective coverage
- **WHEN** the catalog is compared against `assessment/data/tracker.yaml`
- **THEN** every objective subsection resolves to at least one catalog entry

### Requirement: Custom labs follow a standard format
Each lab SHALL state: objectives covered (mapped to tracker ids), prerequisites (which `lab-infra/` components to bring up and which domain notes to read first), estimated time, deploy/config steps, a verification step proving the security control works, and teardown instructions.

#### Scenario: Custom lab structure
- **WHEN** a reader opens any lab under `labs/`
- **THEN** it contains all sections: objectives, prerequisites, estimated time, steps, verification, teardown

#### Scenario: Verification is concrete
- **WHEN** a lab's steps are completed
- **THEN** the verification section gives an observable check (e.g., a denied Kyverno admission, a fired Falco alert, an OIDC token rejected, a Trivy CRITICAL finding, a NetworkPolicy-blocked connection) that confirms the security control functions

### Requirement: Labs teach the SC-500 concept through the OSS tool
Each lab SHALL name the SC-500 control it corresponds to and prove the equivalent control in the OSS stack, so completing the lab evidences the transferable concept (e.g., "Conditional Access" via Keycloak authorization policies; "Azure Policy for AKS" via Kyverno/Gatekeeper; "Microsoft Sentinel analytics rule" via a Wazuh/Sigma detection).

#### Scenario: Concept correspondence stated
- **WHEN** a reader opens any lab
- **THEN** it names the SC-500 control it maps to and its verification proves the OSS equivalent enforces the same security outcome

### Requirement: Walkthrough labs for components impractical to run locally
Topics whose full hands-on practice is impractical on a single host (e.g., multi-node HSM integration, large-scale service mesh) SHALL be covered by walkthrough labs — written configuration sequences with docs and reference output — and explicitly marked `walkthrough` in the catalog; everything runnable on a laptop-class host SHALL be `hands-on`.

#### Scenario: Walkthrough marking
- **WHEN** a topic cannot be practiced hands-on on the reference host
- **THEN** its catalog entry is marked `walkthrough` and the lab still enumerates the exact configuration steps as if performing them

### Requirement: Lab commands match the component's deployed mode
A lab's step-by-step commands SHALL match the mode and configuration the backing `lab-infra/` component actually deploys, so a learner following the lab never runs an instruction the running tool contradicts or references a file the deployment never generates. Where production-only mechanics (e.g. Shamir seal/unseal, integrated Raft storage) are not exercised by the shipped dev deployment, the lab SHALL present them as read-only reference/walkthrough rather than as commands to run.

#### Scenario: The Vault dev deployment matches the lab narrative
- **WHEN** a learner runs `lab-infra/secrets/up.sh` (dev-mode Vault) and follows `labs/d2-vault-dynamic-secrets.md` Part A
- **THEN** the lab logs in with the dev root token `root`, does not instruct reading a `.vault-init.json` that is never generated, and does not require `raft` storage or Shamir shares that an in-memory dev server cannot provide

#### Scenario: Production seal/storage mechanics are framed as reference
- **WHEN** the lab covers Shamir seal/unseal and integrated Raft storage
- **THEN** these are presented as the commented production path (study material read alongside the dev deployment), not as commands the dev server is expected to execute

### Requirement: Optional enrichment labs are supported and marked as non-tracked
The lab catalog SHALL support an **optional enrichment lab** category: a lab that follows the standard lab format (objectives, prerequisites, estimated time, steps, a concrete verification, teardown) and exercises the existing `lab-infra/` stack, but is **explicitly not mapped to a `tracker.yaml` objective** and is marked as optional/enrichment in `labs/README.md`. Enrichment labs SHALL be exempt from the objective-coverage requirement (they add depth beyond the skills outline, not coverage of it), and the catalog index SHALL distinguish them from tracked hands-on and walkthrough labs so a learner can tell required coverage from optional depth. The first enrichment lab SHALL be a **kubelet attack-surface** lab that probes the kubelet API on the existing `kind` cluster, observes that authentication/authorization is enforced, ties the observed behavior to the `--anonymous-auth` / `--authorization-mode` settings, and connects the CRI/containerd boundary to what Falco/Tetragon observe in Domain 3.

#### Scenario: Enrichment lab is labeled distinctly in the catalog
- **WHEN** a reader opens `labs/README.md`
- **THEN** the kubelet attack-surface lab appears marked as an optional enrichment lab, visually distinct from tracked hands-on and walkthrough labs

#### Scenario: Enrichment labs do not distort objective coverage
- **WHEN** the catalog is compared against `assessment/data/tracker.yaml`
- **THEN** the enrichment lab is not required to map to any objective subsection, and its presence neither adds nor is counted toward objective coverage

#### Scenario: The kubelet enrichment lab has a concrete observable
- **WHEN** a learner runs the kubelet attack-surface lab against the `kind` cluster
- **THEN** the verification step gives an observable check — e.g. an unauthenticated request to the kubelet API returning 401/403, contrasted with the kubelet flags that enforce it — proving the kubelet's authn/authz posture rather than merely describing it

#### Scenario: Enrichment lab follows the standard format and tears down cleanly
- **WHEN** a reader opens the kubelet attack-surface lab
- **THEN** it contains objectives, prerequisites, estimated time, steps, verification, and teardown, and its teardown leaves no residual resources on the shared `kind` cluster

### Requirement: The Sigma conversion step is completable from course materials
A lab that requires converting a Sigma rule SHALL teach how to discover the right pipeline (`sigma list pipelines`) and name the correct pipeline for the rule's `product`/`service`, and every reference solution SHALL show a pipeline that matches the rule (not a mismatched one).

#### Scenario: Linux/sshd rule uses a matching pipeline
- **WHEN** a learner completes `labs/d4-siem-wazuh.md` Part C converting a `product: linux, service: sshd` rule
- **THEN** the lab teaches `sigma list pipelines`, names the correct opensearch/linux pipeline, and both the lab reference solution and the `siem-incident-response.md` `siem-detect` note example use that pipeline rather than `-p ecs_windows`

### Requirement: The WAF reference configuration loads without error
A lab's WAF reference configuration SHALL load cleanly — no duplicate rule IDs — and where custom `SecRule` authoring is in exam scope the materials SHALL show a minimal `SecRule` example (or explicitly mark it beyond-lab).

#### Scenario: WAF reference loads and SecRule anatomy is shown
- **WHEN** a learner applies the `labs/d2-ingress-waf.md` Part C reference configuration
- **THEN** it uses a single combined `SecAction` (no duplicate `id:900110`) so ModSecurity loads it without a config-load error, and a minimal `SecRule ARGS "@rx …" "id:…,phase:2,deny"` example is provided or the gotcha is marked beyond-lab

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

### Requirement: A lab's environment can physically produce its stated observable
Before a lab is marked valid, its environment SHALL be able to produce the observable the lab claims. In particular, a lab exercising a browser security-context API SHALL run in a secure context, and every lab with a positive/observable check SHALL have that check verified end-to-end at least once.

#### Scenario: WebAuthn runs in a secure context
- **WHEN** the D1 Keycloak SSO/MFA Part C passkey exercise is run
- **THEN** the origin is a browser secure context (Keycloak fronted with TLS, or port-forwarded to literal `localhost` with RP ID `localhost`, and the lab states which), so `navigator.credentials.create` is available and the passwordless and RP-ID-mismatch observables are reachable

#### Scenario: One SIEM alert is verified end-to-end
- **WHEN** the SIEM lab is validated
- **THEN** at least one alert is confirmed from generated telemetry through to a parsed alert before the lab is marked valid, rather than the stages producing zero alerts with zero errors

#### Scenario: Mesh authorized call returns 200
- **WHEN** the D2 network-policy Part B authorized call is made using the single agreed principal
- **THEN** it returns 200, confirming the "authorized call → 200" observable is reachable on both the lab and reference paths

