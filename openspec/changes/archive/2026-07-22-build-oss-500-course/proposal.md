## Why

The SC-500 study system (`../scc-500`) teaches Cloud and AI security engineering, but every hands-on lab is bound to Microsoft Entra, Azure, and Defender — it needs a paid Azure subscription plus expiring trials (~$500 budget) and frames skills in vendor-specific terms. This change builds **OSS-500**: a parallel curriculum that teaches the *same* SC-500 concepts (identity, secrets, container/compute security, network segmentation, posture monitoring, SIEM, governance, AI security) on a 100% open-source stack (Keycloak, Vault, Kubernetes, Falco, Prometheus/Grafana/Loki, Wazuh, Trivy/Grype/Kubescape, OPA/Kyverno, Ollama). It runs locally for **$0**, has no expiring trials, and produces skills portable across Azure, AWS, GCP, and on-prem — while doubling as a portfolio artifact.

**oss-500 is a pure-content course repo.** The rendering app already exists: `../study-hub` is a course-agnostic study app (dashboard, plan/notes/labs browser, tracker, quiz runner, cross-linking, search) that consumes course repos as git submodules under `content/` and normalizes each via a thin per-course adapter. scc-500, tf-004, and modern-security-lab are already wired in. oss-500 becomes the fourth course. This change therefore builds **content + lab infrastructure only** and wires oss-500 into study-hub — it does **not** build another UI.

## What Changes

- **New content-only repository `oss-500/`** with `plan/`, `domains/`, `labs/`, `lab-infra/`, and `assessment/data/` — matching study-hub's ingestion layout so it renders with no bespoke app.
- **Concept-parity curriculum** under `domains/`: the four SC-500 domains and their exam weights kept as the organizing spine, each objective mapped to its OSS-equivalent tool and the transferable concept beneath it.
- **Hands-on labs on free, local infrastructure**: deploy → configure → verify-the-control → tear-down loops for Keycloak SSO/MFA, Vault dynamic secrets, cert-manager, Kubernetes RBAC/NetworkPolicy/PodSecurity, Kyverno/OPA Gatekeeper admission, Falco/Tetragon runtime detection, Trivy/Grype/Kubescape scanning, Prometheus/Grafana/Loki observability, Wazuh SIEM + Suricata/Zeek, and Ollama/Open WebUI AI-security with guardrails.
- **Reproducible lab infrastructure as code** under `lab-infra/`: a **kind**-based lab cluster provisioned via Helm values/manifests for in-cluster components plus Docker Compose for standalone appliances — replacing Azure Terraform. No cloud provider, no cost/trial timeline.
- **Assessment data** (`tracker.yaml` + `quiz-*.yaml`) authored to study-hub's shared model, with per-domain checkpoint quizzes written to the concepts (not dumps) and a readiness gate.
- **study-hub integration**: add oss-500 as `content/oss-500`, write a thin `oss500` adapter (derived from the scc-500 adapter, `weekPaced: false` so the Azure trial-clock widgets don't render), and add one registry line.
- **Portfolio hygiene**: no secrets committed; a professional root README presenting the repo as a Cloud/AI-security work sample.

## Capabilities

### New Capabilities
- `oss-curriculum`: Study notes under `domains/` covering the four SC-500 domains, mapping each objective to its OSS equivalent and the underlying transferable concept, with curated OSS resources per objective and deep-dive AI-security coverage.
- `study-schedule`: A phased learning path under `plan/` (fundamentals ramp + four domain phases + review) calibrated to SC-500 domain weights, with a local resource/time budget instead of a cloud cost timeline.
- `hands-on-labs`: A lab catalog under `labs/` with a standard custom-lab format (objectives, prerequisites, time, steps, verification, teardown) and objective-to-lab mapping.
- `lab-infrastructure`: Reproducible IaC under `lab-infra/` (kind + Helm/manifests + Docker Compose) with an independent deploy–verify–destroy loop per lab and annotated security controls that double as study material.
- `assessment-tracking`: An objective coverage tracker (`tracker.yaml`/`tracker.md`), per-domain checkpoint quizzes, and a readiness gate under `assessment/`.
- `study-data-format`: `tracker.yaml` and `quiz-*.yaml` authored to study-hub's shared content model, using resolvable objective-id and doc-path reference conventions so study-hub's tracker, quiz runner, and cross-linking work unmodified.
- `study-hub-integration`: Wire oss-500 into `../study-hub` as a `content/` submodule with a per-course adapter and registry entry, so the existing app renders it with no per-course UI.
- `portfolio-repo`: Public-portfolio safety (no secrets/identifiers committed) and portfolio-quality presentation.

### Modified Capabilities
- None in oss-500 (`openspec/specs/` is empty). The `study-hub-integration` capability's implementation edits sibling files in `../study-hub` (`.gitmodules`, `src/content/registry.ts`, a new `src/content/adapters/oss500.ts`); those are additive and covered by study-hub's own `lint:content` and test suite.

## Impact

- **New repo tree**: `plan/`, `domains/`, `labs/`, `lab-infra/`, `assessment/data/`, root `README.md`, `.gitignore`. **No `ui/`** — rendering is study-hub's job.
- **Edits in `../study-hub`**: `.gitmodules` (+1 submodule), `src/content/registry.ts` (+1 line), new `src/content/adapters/oss500.ts` (thin, derived from `scc500.ts`), and optionally a `lab-infra/*/README.md` glob in `src/content/raw.ts` if lab-infra READMEs should be browsable in-app.
- **Learner-side tools** run locally: Docker, kind, Helm, kubectl for labs; Node 22 to run study-hub. The OSS security tools are deployed by the labs themselves.
- **No cloud accounts, no paid services, no expiring trials** — the primary divergence from `scc-500`, which removes the cost timeline and makes the dashboard's trial clocks inert via `weekPaced: false`.
- **Source of truth for coverage**: `assessment/data/tracker.yaml`. Validation is study-hub's `npm run lint:content` (unique ids, resolvable objective refs, notes-path existence, in-range answers).
