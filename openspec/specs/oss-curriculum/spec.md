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

