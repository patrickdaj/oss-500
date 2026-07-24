# lab-infrastructure Specification

## Purpose

OSS-500's labs need a reproducible, local, single-host OSS security stack provisioned as code. This capability defines the `lab-infra/` layer: independently-bringable components as code, a deploy–verify–destroy workflow per lab, resource guardrails and labeling for a laptop-class host, security-relevant settings annotated so the IaC doubles as study material, and a per-component README following the scc-500 model.
## Requirements
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

### Requirement: Related lab-infra stacks share common scaffolding and the shared namespace scheme

A family of near-identical `lab-infra/` stacks (e.g. the ZTNA Terraform stacks `ztna-boundary`, `ztna-netbird`, `ztna-openziti`, `ztna-pomerium`) SHALL factor their shared scaffolding — the `up`/`down` bring-up/teardown flow, the tfvars-missing guard, and the common `versions`/`terraform.tfvars.example` boilerplate — into a single shared location rather than duplicating it per stack, WHILE keeping each stack's per-model `main.tf` in place, in full, as readable study material. In-cluster stacks in such a family SHALL join the shared PSA-labelled `oss500-*` namespace scheme in `lab-infra/shared/namespaces.yaml` rather than self-creating a bespoke namespace, or SHALL document inline why they opt out.

#### Scenario: Boilerplate is factored, per-model main.tf stays readable in place

- **WHEN** a reader opens any stack in a family of near-identical lab-infra stacks
- **THEN** the shared bring-up/teardown flow, tfvars guard, and common `versions`/`tfvars` boilerplate resolve to one shared definition (not copied into every stack), and that stack's own `main.tf` — the per-model Terraform the learner is meant to study — is still present in the stack directory, unchanged and readable without following an indirection

#### Scenario: A change to the shared scaffolding is made once

- **WHEN** the shared bring-up/teardown flow or the tfvars-missing guard for a stack family must change
- **THEN** the edit is made once in the shared location and takes effect for every stack in the family, rather than being repeated per stack

#### Scenario: In-cluster stacks use the shared PSA-labelled namespace scheme

- **WHEN** an in-cluster stack in the family is deployed (e.g. the Pomerium identity-aware proxy)
- **THEN** its resources land in an `oss500-*` namespace from `lab-infra/shared/namespaces.yaml` carrying `app.kubernetes.io/part-of: oss500` and a `pod-security.kubernetes.io/enforce` label, so a single `part-of=oss500` query returns them for teardown — or the stack documents inline why it opts out of the shared profile

#### Scenario: The refactor does not change what a stack teaches

- **WHEN** a stack's `main.tf`, objective ids, and deploy–verify–destroy observable are compared before and after the scaffolding is extracted
- **THEN** they are unchanged — only boilerplate was factored out, so the study value and the lab's coverage are preserved

### Requirement: Companion Compose services join the primary stack's network
When a `lab-infra/` component is a multi-file Docker Compose stack whose companion services (such as an onboarded agent) must reach the primary services, all files SHALL be brought up under the same Compose project name and the companion SHALL attach to the network that project actually creates, so companion services can resolve and reach the primary services.

#### Scenario: The Wazuh agent lands on the manager's network
- **WHEN** a learner brings up the SIEM with `docker compose -p oss500-siem` and then onboards the agent from `agent-compose.yml` under the same project
- **THEN** the agent attaches to `oss500-siem_default` (the network that project creates), resolves `wazuh.manager`, and enrolls — rather than failing because the file names a different, non-existent external network

#### Scenario: Onboarding-dependent lab stages are reachable
- **WHEN** the agent has enrolled
- **THEN** the SIEM collect, detect, hunt, and response stages can be exercised against real agent-sourced events

### Requirement: A lab's prove-it observable is reproducible from the shipped component
Every backend, service, credential, or client that a lab's verification step depends on SHALL be created by that lab's backing `lab-infra/` component `up.sh` (or by the lab's own explicit steps) — never assumed to exist. A lab SHALL NOT reference a manifest, host, or namespace that the component does not actually provide.

#### Scenario: The dynamic-secrets lab has its database backend
- **WHEN** a learner runs `lab-infra/secrets/up.sh` and follows `labs/d2-vault-dynamic-secrets.md` Part C
- **THEN** a Postgres Deployment and Service exist at the host the lab names, and a psql-capable client is available, so `vault write database/config/appdb` connects and the dynamic credential can be tested

#### Scenario: Lease revocation is observable end to end
- **WHEN** the learner reads a dynamic credential, uses it against Postgres, then revokes the lease (or waits for TTL expiry)
- **THEN** the credential is accepted before revocation and rejected after — the `vault-dynamic` observable — rather than failing at `vault write database/config` because no database exists

#### Scenario: No dangling references to absent resources
- **WHEN** the lab or the component's scripts name a manifest, host, or namespace (e.g. `postgres.oss500-secrets`)
- **THEN** that resource is actually created by the component and the scripts and lab agree on one name (no `postgres.yaml` that does not exist, no namespace mismatch between `configure.sh` and the lab)

### Requirement: The AI lab deploys enforcing guardrails and gateway in the request path
The `lab-infra/ai/` component SHALL deploy an AI gateway and NeMo Guardrails as running workloads that sit in the request path in front of Ollama, so that every prove-it observable in the Domain 3 AI-security lab and the Domain 5 AI red-team lab is reproducible from `up.sh` as shipped. Guardrail and policy configuration SHALL be loaded by a running workload, not left as inert ConfigMaps, and Ollama SHALL be reachable only through the gateway.

#### Scenario: The gateway is a real, reachable workload
- **WHEN** a learner runs `lab-infra/ai/up.sh` and issues a request to the gateway Service on its documented port
- **THEN** an `ai-gateway` Deployment and Service are running in `oss500-apps` and answer the request (rather than returning a name-resolution error for a Service that does not exist)

#### Scenario: Authentication and rate limiting are enforced
- **WHEN** a learner calls the gateway with no valid token, and separately floods it past its rate limit
- **THEN** the gateway returns `401` for the unauthenticated call and `429` for the rate-limited call

#### Scenario: Input and output rails execute in-path
- **WHEN** a learner sends a jailbreak prompt, and separately asks the model to repeat a seeded secret
- **THEN** the input rail refuses the jailbreak, the output rail redacts the secret, and a `guardrail.blocked` OpenTelemetry span is emitted — while a benign prompt is answered normally

#### Scenario: Ollama is only reachable through the gateway
- **WHEN** a pod that is not the gateway or guardrails attempts to reach Ollama on `:11434`
- **THEN** the Ollama NetworkPolicy denies it, so the gateway is the only legitimate path to the model

#### Scenario: The Domain 5 AI red-team target stands up
- **WHEN** the Domain 5 AI red-team lab fires garak at the guardrailed gateway
- **THEN** the gateway target is running and reachable, so the defended-vs-baseline comparison can be performed rather than attacking a target that was never deployed

### Requirement: Every CLI a lab invokes has a documented install source
Every command-line tool a lab invokes beyond the day-one baseline (Docker, kind, kubectl, Helm, git) SHALL have a documented install source: a central tools manifest (`TOOLS.md`) listing each tool, the phase it first appears, and how to install it per OS, plus a per-lab prerequisite that names the non-baseline CLIs that lab uses and links the manifest. No lab step SHALL fail on an un-obtained, unpointed binary. Tools whose absence hard-fails a bring-up script (Terraform, `jq`) SHALL additionally appear in the top-level prerequisite lists.

#### Scenario: A central tools manifest covers every invoked CLI
- **WHEN** a lab invokes a CLI (e.g. `terraform`, `vault`, `boundary`, `opa`, `cmctl`, `trivy`, `jq`)
- **THEN** that tool appears in `TOOLS.md` with the phase it first appears and a per-OS install command, so the learner can obtain it without a search

#### Scenario: A lab names its non-baseline tools
- **WHEN** a learner opens a lab that uses tools beyond Docker/kind/kubectl/Helm/git
- **THEN** the lab's Prerequisites name those CLIs and link `TOOLS.md`, rather than assuming the binary is already present

#### Scenario: Script-critical tools are listed as prerequisites
- **WHEN** a bring-up script hard-fails without a tool (e.g. `ztna-common/tf.sh` needs `terraform`; `lab-infra/secrets/up.sh` needs `jq`)
- **THEN** that tool is listed in the top-level `README.md` / `lab-infra/README.md` prerequisites with an install link, not only inside a later note

### Requirement: The AI red-team labs ship runnable offense scaffolding

`lab-infra/offense/` SHALL ship runnable scaffolding for the AI red-team tracks: a PyRIT multi-turn orchestrator skeleton wired to the local Ollama/gateway target, and a garak generator-config example (`localhost-ollama.json` for the REST generator) that points garak at the local stack. Both SHALL run against the local lab stack out of the box — `garak -G lab-infra/offense/localhost-ollama.json …` targets the local gateway without edits, and the PyRIT skeleton executes a minimal multi-turn run — and both SHALL be shaped as scaffolds the learner extends, not finished exploits.

#### Scenario: garak targets the local stack from the shipped config

- **WHEN** a learner runs garak with the shipped `-G localhost-ollama.json` generator config against the running AI gateway/Ollama
- **THEN** garak connects to the local target and runs, with no undocumented JSON the learner had to reverse-engineer from the garak docs

#### Scenario: The PyRIT skeleton runs a multi-turn orchestration

- **WHEN** a learner runs the shipped PyRIT orchestrator skeleton against the local target
- **THEN** it executes a minimal multi-turn orchestration the learner can extend, rather than starting from an empty file and a bare GitHub link

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

