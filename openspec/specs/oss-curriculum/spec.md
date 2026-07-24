# oss-curriculum Specification

## Purpose

OSS-500 mirrors the SC-500 skills outline but teaches every objective through its open-source equivalent. This capability defines the study-notes curriculum under `domains/`: concept-parity coverage of every outline bullet organized by SC-500 domain and weight, an explicit SC-500-to-OSS concept mapping per objective joined by stable ids, curated per-objective resources, and deep-dive coverage of the newest AI-security material.
## Requirements
### Requirement: Concept-parity coverage of the SC-500 skills outline
The curriculum SHALL contain study notes under `domains/` organized as one directory per SC-500 exam domain and one markdown file per skills-outline subsection, where every objective bullet of the official SC-500 study guide appears as a heading with substantive study content beneath it, taught through its open-source equivalent. The four domain directories SHALL preserve the SC-500 domains and their exam weights as the organizing spine: identity/access/governance, secrets/data/networking, compute-and-AI, and posture/monitoring.

#### Scenario: Every objective bullet is present
- **WHEN** any bullet from the official SC-500 "Skills measured" outline is searched for in `domains/`
- **THEN** a matching heading exists with explanatory content (the transferable concept, the OSS tool that implements it, key configuration steps, and gotchas) beneath it

#### Scenario: Domain directories mirror the outline and weights
- **WHEN** a reader lists `domains/`
- **THEN** they see four directories matching the four SC-500 domains (plus an optional `0-` fundamentals ramp), each containing one file per official subsection

### Requirement: Each objective maps SC-500 concept to OSS equivalent
Each objective's notes SHALL carry a metadata line linking its stable objective `id`, its lab, and the transferable concept, and SHALL explicitly name both the SC-500 technology and its open-source equivalent (e.g., Entra ID PIM → Teleport/Boundary just-in-time access; Azure Key Vault → HashiCorp Vault; Defender for Containers → Falco/Tetragon).

#### Scenario: Concept mapping is explicit
- **WHEN** a reader opens the notes for any objective
- **THEN** the notes state the SC-500 technology, its OSS equivalent, and the underlying concept that transfers across clouds, with a metadata line linking the objective id and its lab

#### Scenario: Objective ids join across artifacts
- **WHEN** an objective's id is read from a domain file's metadata line
- **THEN** the same id resolves in `assessment/data/tracker.yaml` and is referenceable from labs and quizzes

### Requirement: Curated OSS resources mapped per objective
Each subsection SHALL list curated study resources per objective — official project documentation, upstream tutorials/guides, and reputable video or conference talks — each annotated with an estimated time, prioritizing free and authoritative sources.

#### Scenario: Resources accompany each objective
- **WHEN** a reader finishes the notes for an objective
- **THEN** they find a resource list with at least one official documentation link, annotated with an estimated completion time

### Requirement: AI-security topics receive deep-dive coverage
AI-security objectives (prompt-injection mitigation, model access control, LLM observability, secure RAG, AI governance, data protection) SHALL be flagged as concept-new and receive dedicated deep-dive content built on the OSS AI stack (Ollama, Open WebUI, NeMo Guardrails / guardrails, OPA), since these map to the newest SC-500 material.

#### Scenario: AI depth
- **WHEN** a reader opens the AI-security file in the compute-and-AI domain
- **THEN** every AI objective bullet has dedicated content plus doc links, a runnable OSS lab reference, and the file is flagged as concept-new

### Requirement: Cross-cutting control mechanics are single-sourced and cross-linked
When a control mechanic applies across more than one SC-500 domain (e.g., admission policy-engine internals, secret injection, image signing), the curriculum SHALL teach that mechanic in full in exactly one **canonical** note — the note owning the objective for which the mechanic is the primary subject — and every other note that relies on it SHALL cross-link the canonical note rather than re-deriving the mechanic. A non-canonical note SHALL restate only its own domain-specific delta (how the shared mechanic is *applied* in that domain), not the shared mechanic itself, so a shared mechanic has a single source of truth and cannot drift between notes.

#### Scenario: Admission policy-engine mechanics live only in governance.md
- **WHEN** a reader opens `domains/3-compute-ai/pod-security.md` and reaches the `pod-admission` section
- **THEN** the engine internals (Kyverno/Gatekeeper authoring models, `Enforce` vs `Audit`, webhook `failurePolicy` fail-open/closed, `kube-system` exemption, the "Azure Policy for AKS is Gatekeeper" anchor) are cross-linked to the canonical `gov-gatekeeper`/`gov-kyverno` sections of `domains/1-identity-governance/governance.md` and not re-taught, while the section still teaches inline its pod-specific delta — the PSA-vs-policy-engine boundary and mutation-runs-before-validation to auto-harden pods

#### Scenario: A duplicated mechanic is detected as a defect
- **WHEN** a reviewer finds the same control mechanic taught in full in two different `domains/` notes
- **THEN** it is treated as a single-sourcing violation: one note is designated canonical and the other is reduced to its domain-specific delta plus a cross-link to the canonical note

### Requirement: Overlapping tool families have a selection orientation
When the curriculum teaches multiple tools of the same family across different notes — in particular the multiple certificate authorities (cert-manager, Vault PKI, the Istio/Linkerd mesh CA, and the SPIRE trust-domain CA) — one note SHALL provide a single selection orientation mapping each tool to the use case it owns (edge/ingress TLS vs east-west mesh mTLS vs platform-agnostic SPIFFE SVID vs app/internal PKI), and the other notes teaching a member of that family SHALL cross-reference it, so the learner has one place that contrasts their scopes rather than reconstructing the mapping from scattered coverage.

#### Scenario: A CA-to-use-case map orients the four certificate authorities
- **WHEN** a learner has met the four certificate authorities across `keys-and-certificates.md`, `network-security.md`, and `workload-identity.md`
- **THEN** `keys-and-certificates.md` contains a CA-selection orientation box mapping each CA to its use case (cert-manager → edge/ingress and app TLS lifecycle, Vault PKI → app/internal PKI, Istio/Linkerd CA → east-west mesh mTLS, SPIRE → platform-agnostic SPIFFE SVID), and the mesh note (`net-mesh`) and SPIFFE note (`wi-spiffe`) each cross-link to that box

### Requirement: A shared tool-and-skill is taught once and applied by reference
When two or more objectives use the **same open-source tool to teach the same underlying skill** (the same command/mechanic mapped to the same SC-500 control), exactly **one** objective SHALL be the canonical teaching location that explains the mechanics, and every other objective SHALL frame that skill as an **application in its own domain context** and defer the mechanics to the canonical location by an explicit cross-reference, rather than re-teaching them. Both objectives SHALL remain present in `assessment/data/tracker.yaml` with descriptions differentiated by their domain lens, so shared-tool reuse never duplicates instruction and never removes coverage.

#### Scenario: Kubescape compliance-scoring is taught once and applied by reference
- **WHEN** a reader compares `gov-compliance` in `domains/1-identity-governance/governance.md` with `vuln-compliance` in `domains/4-posture-monitoring/vulnerability-posture.md`, both of which use `kubescape scan framework` to produce a compliance score mapped to Defender secure score / regulatory compliance
- **THEN** `vuln-compliance` SHALL be the canonical location teaching the scoring mechanics (framework scans, compliance %/secure-score, report formats, and the "score is not a formal certification" caveat), `gov-compliance` SHALL frame the skill as a governance-context application (measure the estate as the detective half of the enforce/measure loop) and cross-reference `vuln-compliance` for the mechanics instead of re-teaching them, and both objective ids SHALL still resolve in `assessment/data/tracker.yaml` with differentiated descriptions

### Requirement: LLM mechanics are taught in an AI on-ramp before ai-security.md assumes them
The curriculum SHALL contain an LLM-mechanics primer — as a `0-fundamentals` note or a D3 preamble placed ahead of `domains/3-compute-ai/ai-security.md` — that teaches token and tokenization, the context window, the system-vs-user prompt split, embeddings, vector stores, and the RAG retrieve→augment→generate loop. The primer SHALL define this vocabulary sufficiently for the learner to follow `ai-security.md`'s threat model from course materials alone, SHALL be flagged concept-new (consistent with the AI-security notes), and SHALL be cross-linked from `ai-security.md` and the secure-RAG objective rather than duplicated. The change SHALL NOT remove or rewrite the existing `ai-security.md` threat-model content, which the audit judged strong.

#### Scenario: The assumed AI vocabulary is defined before it is used
- **WHEN** a learner opens `ai-security.md`, which reasons over tokens, context windows, prompts, embeddings, vector stores, and RAG
- **THEN** a linked LLM-mechanics primer has already defined each of those terms, so the AI-newcomer persona can follow the threat model without leaving the course

#### Scenario: The RAG loop is walked before secure-RAG uses it
- **WHEN** a learner reaches the secure-RAG objective
- **THEN** the primer has already walked the retrieve→augment→generate loop, and the secure-RAG note cross-links it rather than re-explaining RAG

#### Scenario: The existing threat model is preserved
- **WHEN** the primer is added
- **THEN** `ai-security.md`'s threat-model teaching is left intact and the primer sits beneath it as the missing mechanics substrate

### Requirement: OAuth 2.0 / OIDC / JWT anatomy is taught before D1 assumes it
The curriculum SHALL contain an OAuth 2.0 / OIDC / JWT anatomy primer — as a `0-fundamentals` note or a D1 preamble placed ahead of `identity-provider` — that walks the authorization-code flow end to end (including PKCE) and situates the other four grant types against it, distinguishes the OIDC ID token from the OAuth access token, and decodes a JWT's header and standard claims (`iss`, `aud`, `sub`, `exp`, `iat`, and the `act` actor claim), including how a signature is verified against a JWKS. The primer SHALL let the learner trace at least one full grant flow and read what each decoded-JWT claim gates from course materials alone, and SHALL be cross-linked from `identity-provider` and from the D6 objectives that rely on token-exchange / `act` delegation semantics rather than re-teaching those mechanics.

#### Scenario: A grant flow is walked before identity-provider uses it
- **WHEN** a learner opens `identity-provider`, which names the five grant types
- **THEN** a linked primer has already walked the authorization-code flow end to end (with PKCE) and placed the other grant types against it, so the learner can trace a flow rather than only name one

#### Scenario: Decoded JWT claims are meaningful
- **WHEN** a lab has the learner decode a JWT at `jwt.io`
- **THEN** the primer has already taught what `iss`, `aud`, `sub`, `exp`, `iat`, and `act` each mean and how the signature is verified against a JWKS, so the learner knows which claim gates what

#### Scenario: D6 delegation reuses the same primer
- **WHEN** a learner reaches the D6 objectives that turn on token-exchange and `act` actor-claim delegation
- **THEN** those notes cross-link the same primer rather than re-deriving OAuth/OIDC/JWT semantics

### Requirement: Rego is taught as a language before the first lab authors it
The curriculum SHALL contain a Rego language primer, placed in (or cross-linked from) the note whose lab first requires the learner to author Rego — the D1 `governance` objective — that teaches Rego's declarative evaluation model, rules and rule bodies, partial-set/partial-object collection rules (e.g. `deny[msg] { … }`), navigation of the `input` document, and evaluating a policy with `opa eval`. The primer SHALL be sufficient for the learner to author the `governance` lab Part B violation rule from course materials alone, without reading the upstream OPA language reference first, and SHALL be flagged concept-new because Python fluency does not transfer to Rego's model. Every later objective that authors or evaluates Rego — `ai-governance`, `tool-authz`, `action-class`, and the D6 guardrail objective — SHALL cross-link this primer rather than re-teaching the language.

#### Scenario: The governance lab's first Rego rule is authorable from the note
- **WHEN** a learner reaches the D1 `governance` lab Part B and must author a violation rule
- **THEN** a linked Rego primer in course materials has already taught the declarative model, rule bodies, partial-set collection, `input` navigation, and `opa eval`, so the learner can write the rule without leaving the course for the OPA language reference

#### Scenario: Later Rego objectives reuse the single primer
- **WHEN** a learner reaches `ai-governance` (`opa eval`), `tool-authz`, `action-class`, or the D6 guardrail objective
- **THEN** each note cross-links the same Rego primer rather than re-deriving the language, so Rego is single-sourced across the three domains that use it

#### Scenario: The primer is flagged concept-new
- **WHEN** the networking-strong persona opens the Rego primer
- **THEN** it is flagged concept-new and states plainly that Python fluency does not transfer to Rego's declarative/partial-set evaluation model

### Requirement: An eBPF concept primer precedes the notes that assume eBPF internals
The curriculum SHALL include a short eBPF concept primer positioned at or before the first note that reasons about eBPF internals (no later than the Domain 3 runtime-security note, and reachable from the earlier Domain 2 Cilium material). The primer SHALL cover, at minimum: what eBPF is, hook points (syscalls, kprobes/tracepoints, and the LSM hook), the verifier and why loaded programs are constrained to be safe, the distinction between observe-only (kprobe) and enforce-capable (LSM) attachment, and CO-RE / the modern probe. The notes that use eBPF (runtime-security's Falco/Tetragon and the Cilium material) SHALL cross-link the primer so that the external eBPF introduction is depth rather than a prerequisite.

#### Scenario: The learner understands eBPF before Falco/Tetragon
- **WHEN** a learner reaches the Domain 3 runtime-security note and its Falco/Tetragon material
- **THEN** an eBPF primer has already defined hook points, the verifier, and observe-vs-enforce, so the learner can follow the note without first reading an external eBPF introduction

#### Scenario: Tetragon's in-kernel enforcement is explicable from course material
- **WHEN** the note describes Tetragon enforcing in-kernel (kill/signal on match) versus Falco observing and alerting
- **THEN** the primer's kprobe-vs-LSM distinction makes that difference explicable without leaving the curriculum

### Requirement: Phase 0 teaches authoring a hardened pod manifest
The Phase-0 Kubernetes fundamentals note SHALL teach the learner to *author* a pod manifest — a complete hardened pod YAML carrying `runAsNonRoot`, `runAsUser`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, resource `limits`, and a probe — applied with `kubectl apply` and verified, rather than teaching only imperative `kubectl create`/`kubectl run`. It SHALL also show the learner how to read a generated spec (for example `kubectl get deploy nginx -o yaml`) so they can connect an imperative command to the declarative object it produces.

#### Scenario: The learner writes a hardened pod spec before the admission labs
- **WHEN** a learner completes the Phase-0 Kubernetes fundamentals note
- **THEN** they have authored and applied a pod manifest with a hardened `securityContext`, resource limits, and a probe, before Phase 1 Days 3/5 and the pod-security/admission labs require that skill

#### Scenario: The hardening is demonstrated as enforced, not just declared
- **WHEN** the learner applies the hardened pod and runs the note's verification step
- **THEN** a write to the read-only root filesystem is denied, so the learner sees the `securityContext` settings take effect rather than only reading them in YAML

#### Scenario: The learner can read a generated spec
- **WHEN** the learner runs an imperative `kubectl` command and then inspects it with `-o yaml`
- **THEN** the note shows the full declarative spec the command generated, bridging imperative use to manifest authoring

### Requirement: Phase 0 has a short RBAC preview backing the Day-4 block
The Phase-0 Kubernetes fundamentals note SHALL contain a short "RBAC in 10 minutes" section covering Roles and ClusterRoles, RoleBindings and ClusterRoleBindings, subjects (ServiceAccount and user), verb/resource rules, and a `kubectl auth can-i` check, so the plan's Day-4 RBAC-preview block has backing content in Phase 0 rather than forward-referencing the full Phase-1 RBAC deep-dive the learner reaches weeks later.

#### Scenario: The Day-4 RBAC-preview block has something to read
- **WHEN** a learner reaches the plan's Day-4 RBAC-preview block
- **THEN** the Phase-0 Kubernetes note provides a short RBAC preview (Roles/ClusterRoles, bindings, subjects, verb/resource rules, and `kubectl auth can-i`) that the block can point at, instead of the block only forward-referencing the Phase-1 deep-dive

#### Scenario: The preview does not duplicate the Phase-1 deep-dive
- **WHEN** the RBAC preview is authored
- **THEN** it is scoped as a 10-minute orientation and cross-links the canonical Phase-1 RBAC note for depth, rather than re-teaching the full RBAC objective in Phase 0

### Requirement: A cluster-internals security primer teaches the control-plane trust model as attack surface
The curriculum SHALL include a short cluster-internals *security* primer, positioned in or adjacent to the Phase-0 Kubernetes note (`domains/0-fundamentals/02-kubernetes.md`) and reachable before the notes that assume these internals. The primer SHALL cover, at minimum: the cluster **CA / PKI mesh** (every control-plane and node component authenticates with a certificate chained to the cluster CA, so the CA is the root of cluster trust); the **API server** as the single authenticated front door; **etcd** as the store of all cluster state and its unencrypted-at-rest default; the **kubelet** as a network-reachable API (port 10250, the `--anonymous-auth` and `--authorization-mode` settings) and therefore an attack surface; the **CRI / containerd** boundary as where runtime instrumentation (Falco/Tetragon) hooks; and the **CNI** as the seam where NetworkPolicy is or is not enforced. The primer SHALL frame all of this as a security lens on the existing `kind` cluster, SHALL state that the course keeps `kind` rather than adopting a from-scratch build, and SHALL name *Kubernetes The Hard Way* (kubeadm/containerd/CNI bootstrap) as optional depth rather than a required step. The notes that rely on these internals (Kubernetes RBAC, runtime-security, NetworkPolicy, etcd/data encryption) SHALL cross-link the primer.

#### Scenario: The learner meets the cluster trust model before the notes that assume it
- **WHEN** a learner reaches the RBAC, runtime-security, or NetworkPolicy notes that reason about the kubelet, the CRI boundary, or component-to-component trust
- **THEN** the cluster-internals security primer has already defined the CA/PKI mesh, the kubelet API surface, the CRI boundary, and the CNI enforcement seam, so those notes read standalone

#### Scenario: The kubelet is presented as attack surface, not just a node agent
- **WHEN** the primer describes the kubelet
- **THEN** it identifies the kubelet as a reachable API (10250) whose exposure is governed by `--anonymous-auth` and `--authorization-mode`, so the learner can reason about what a misconfigured kubelet leaks

#### Scenario: From-scratch build is offered as optional depth, not the critical path
- **WHEN** a learner wants the full kubeadm/containerd/CNI bootstrap experience
- **THEN** the primer points to *Kubernetes The Hard Way* as optional external depth while stating the course itself stays on `kind`, so cluster bootstrap never becomes a prerequisite

#### Scenario: No new tracked objective is introduced
- **WHEN** the primer is added and `assessment/data/tracker.yaml` is compared before and after
- **THEN** no objective is added or changed, because the primer is ramp material citing external sources under the `resource-citation` standard

### Requirement: A note's enforcement story matches the lab it prepares
A prerequisite note SHALL describe the enforcement point (which component installs, which enforces, which is optional) exactly as the lab and `lab-infra/` actually implement it, so a reader who reads the note before the lab is not left unsure whether the control is even enforced.

#### Scenario: CNI/Calico story agrees across note, lab, and infra
- **WHEN** a reader compares `domains/2-secrets-data-networking/network-security.md` against `labs/d2-network-policy.md` and `lab-infra/network/up.sh`
- **THEN** the note states that no CNI is installed, that kindnet enforces the Part A NetworkPolicy, and that Calico is optional/manual — matching the lab — rather than claiming the course "installs Calico" and that kindnet is limited

### Requirement: The note teaches the PromQL constructs its flagship example uses
The `obs-alerting` note SHALL teach the PromQL constructs it relies on — instant vs range vectors and vector matching — before or where it presents its headline security alert, and its worked example SHALL be syntactically valid and reference a metric the lab actually exposes.

#### Scenario: Vector matching is taught and the example parses
- **WHEN** a zero-Prometheus learner reads the `obs-alerting` headline alert in `domains/4-posture-monitoring/observability.md`
- **THEN** the note has introduced instant-vs-range vectors and `on(...) group_left` vector matching, the garbled `unless` expression is repaired to valid PromQL, and the privileged-pod metric (`kube_pod_spec_containers_security_context_privileged`) is confirmed exposed by the lab's kube-state-metrics (or the example uses one that is)

### Requirement: The note connects the log-derived metric to the alert
Where a lab builds a detection as a LogQL expression in one part and evaluates it as a Prometheus rule in another, the note SHALL teach the mechanism that bridges them (log-derived metric / Loki ruler), so a learner following the earlier part writes a rule that actually evaluates.

#### Scenario: LogQL rate and Prometheus alert connect
- **WHEN** a learner reads `obs-alerting` after building the Part B LogQL rate and reaches the Part E `authlog_failed_logins_total` alert
- **THEN** the note explains the log-derived-metric / Loki-ruler mechanism that turns the LogQL detection into an evaluable counter, rather than the alert silently switching data sources with no bridge

### Requirement: The note teaches Vault KV-v2 path and template dualities
The Vault notes SHALL explain KV-v2's `data/` path infix (why the policy uses `secret/data/app/*` while CLI reads use `secret/app/...`) and the KV-v2-vs-dynamic response shape with a short Go-template primer, so the policy, CLI, and injector-template examples are internally consistent and a first-time user does not fail on the mismatch.

#### Scenario: Path duality and template shape are taught
- **WHEN** a learner reads `secrets-management.md` (`vault-access` / `vault-k8s`) alongside `labs/d2-vault-k8s-injection.md`
- **THEN** the note explains the `secret/data/` vs `secret/app` path duality and the KV-v2 response shape (`{{ .Data.data.username }}` vs `{{ .Data.username }}`), so the policy, CLI, and injector-template examples agree

### Requirement: The note teaches static-pod editing safety and recovery
Where a lab has the learner hand-edit a static-pod manifest on the node (e.g. `kube-apiserver.yaml`), the note SHALL teach the static-pod model, kubelet's manifest-watch, and how to recover when the apiserver will not return (no `kubectl`; `docker exec` + revert).

#### Scenario: Static-pod recovery is covered before the edit
- **WHEN** a learner reads `data-protection.md` `data-encrypt` before editing `/etc/kubernetes/manifests/kube-apiserver.yaml`
- **THEN** the note explains that the file is a static-pod manifest the kubelet watches and applies, and gives a recovery path for when the apiserver does not come back, rather than leaving the learner with no safety net

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

