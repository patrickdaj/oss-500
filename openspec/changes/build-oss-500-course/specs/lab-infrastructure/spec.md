## ADDED Requirements

### Requirement: Reproducible local lab stack as code
The lab infrastructure SHALL live under `lab-infra/` and provision the OSS security stack locally as code: a `kind` cluster definition, Helm values and/or Kubernetes manifests for in-cluster components (Keycloak, Vault, cert-manager, Harbor, Kyverno, OPA Gatekeeper, Falco, Tetragon, Prometheus/Grafana/Loki/Tempo, Kubescape, Trivy, Ollama/Open WebUI), and Docker Compose for standalone services (Wazuh, OpenSearch, Suricata, Zeek). Each lab SHALL be bringable up independently and idempotently.

#### Scenario: Lab component deploys independently
- **WHEN** the documented bring-up command for any lab is run
- **THEN** that lab's stack provisions without requiring an unrelated lab's components to be running

#### Scenario: Shared building blocks are reused
- **WHEN** two labs need the same base (e.g., the kind cluster or the ingress controller)
- **THEN** both compose the same shared `lab-infra/` definition rather than duplicating it

### Requirement: Deploy–verify–destroy workflow documented per lab
Each lab SHALL document a full loop: bring up, perform the exercise, verify the security control, tear down — with teardown completing cleanly (no orphaned containers, volumes, or cluster resources requiring manual cleanup).

#### Scenario: Clean teardown
- **WHEN** the documented teardown command is run after completing a lab
- **THEN** all lab resources are removed and a follow-up status check shows no remaining managed resources for that lab

### Requirement: Resource guardrails for a single host
`lab-infra/` SHALL document the host resource footprint (CPU/RAM/disk) of each component and a consistent naming/labeling convention (e.g., an `oss500` namespace prefix and label) so a learner on a laptop-class machine can bring up only what a lab needs and identify all lab resources for cleanup.

#### Scenario: Footprint is documented
- **WHEN** a reader opens `lab-infra/README.md`
- **THEN** they find the per-component resource footprint and the minimum host specs to run each phase's labs

#### Scenario: Everything is labeled
- **WHEN** any lab component is deployed
- **THEN** its resources carry the project namespace/label so a single query returns all lab resources for teardown

### Requirement: Infrastructure code doubles as study material
Security-relevant settings in the manifests, Helm values, and compose files SHALL be commented with the SC-500 objective they implement and its OSS concept (e.g., `securityContext.readOnlyRootFilesystem`, NetworkPolicy default-deny, Vault auth roles, Kyverno policies), so reading the IaC is itself study.

#### Scenario: Annotated security controls
- **WHEN** a reader opens any component's manifest or values file
- **THEN** security-relevant settings carry comments naming the SC-500 objective they exercise and the concept they demonstrate

### Requirement: Each lab-infra component has a README, following the scc-500 model
Mirroring scc-500's per-lab `terraform/*/README.md` roots, each `lab-infra/<component>/` directory SHALL contain a `README.md` documenting that component's purpose, bring-up/teardown commands, resource footprint, and the SC-500 objectives it exercises — written so it doubles as an in-app study doc when rendered by study-hub.

#### Scenario: Component README is self-contained
- **WHEN** a reader opens any `lab-infra/<component>/README.md`
- **THEN** it states the component's purpose, its deploy–verify–destroy commands, its footprint, and the objectives it covers, without needing another file to be usable
