## 1. Repo scaffold & portfolio hygiene

- [x] 1.1 Initialize git and create the content tree: `plan/`, `domains/{0-fundamentals,1-identity-governance,2-secrets-data-networking,3-compute-ai,4-posture-monitoring}/`, `labs/`, `lab-infra/`, `assessment/data/` (no `ui/`)
- [x] 1.2 Add `.gitignore` covering kubeconfigs, kind/cluster state, `.env`, Vault tokens/unseal keys, TLS keys, `node_modules/`
- [x] 1.3 Write the root `README.md` (what it demonstrates, SC-500 concept mapping, $0/local, that rendering is via study-hub, repo layout, how to run a lab) — portfolio-quality
- [x] 1.4 Add `*.example` templates for any per-user values labs require

## 2. Assessment data model (defines the objective-id namespace)

- [x] 2.1 Author `assessment/data/tracker.yaml` in study-hub's shape: four domains → subsections → objectives, each objective with stable `id`, SC-500 outline `text`, OSS-equivalent tool, `lab` type; each subsection with a `notes` path to a real `domains/` file
- [x] 2.2 Validate `tracker.yaml` covers every bullet of the official SC-500 skills outline exactly once with unique ids
- [x] 2.3 Add a tiny standalone `scripts/gen-md.mjs` (no app dependency) that regenerates `assessment/tracker.md` and `assessment/checkpoint-*.md` from the YAML

## 3. Study schedule (`plan/`)

- [x] 3.1 Write `plan/overview.md`: phase map (0 fundamentals + 4 domain phases + review), per-domain hours proportional to SC-500 weights, day-structure convention, local-resource readiness section (min host specs, $0 statement)
- [x] 3.2 Write `plan/phase0-fundamentals.md` (Linux/CLI, Docker/OCI, Kubernetes primitives, Helm, kind + IaC primer) using the `- [ ] **[Nh] ...**` block convention study-hub parses
- [x] 3.3 Write the four domain phase plans with day-by-day blocks, milestones, and references to domain notes and labs
- [x] 3.4 Write `plan/review.md`: retake checkpoints, remediation loop, full-stack capstone, readiness gate

## 4. Lab infrastructure (`lab-infra/`, kind)

- [x] 4.1 Write `lab-infra/README.md`: kind cluster bring-up, per-component resource footprints, min host specs (baseline ~16 GB RAM), naming/label convention
- [x] 4.2 kind cluster definition + shared building blocks (ingress, namespaces/labels) reusable across labs
- [x] 4.3 Identity/governance stack: Keycloak, Kubernetes RBAC examples, Kyverno + OPA Gatekeeper, Kubescape — Helm values/manifests with annotated security controls
- [x] 4.4 Secrets/data/networking stack: Vault (+ dynamic secrets), cert-manager, NetworkPolicy sets, a service-mesh/zero-trust example, ModSecurity/NGINX WAF
- [x] 4.5 Compute/AI stack: pod-security + admission policies, Falco, Tetragon, Trivy, Grype, Ollama + Open WebUI + guardrails
- [x] 4.6 Posture/monitoring stack: Prometheus, Grafana, Loki, Tempo, OpenTelemetry; Wazuh + OpenSearch + Suricata + Zeek via Docker Compose
- [ ] 4.7 Verify each stack brings up and tears down cleanly (no orphaned containers/volumes/cluster resources) on the reference host

## 5. Curriculum notes (`domains/`)

- [x] 5.1 Phase-0 fundamentals notes (narrative ramp, self-checks, no objective metadata lines)
- [x] 5.2 Domain 1 notes: one file per subsection, each objective with concept→OSS-equivalent mapping, metadata line (id · lab), gotchas, timed resources, summary table
- [x] 5.3 Domain 2 notes (secrets/data/networking) — same format
- [x] 5.4 Domain 3 notes (compute + AI), with AI-security file flagged concept-new and deep-dived
- [x] 5.5 Domain 4 notes (posture/monitoring/SIEM/vuln-management) — same format
- [x] 5.6 Verify every tracker objective id appears as a heading with content, and every subsection `notes` path resolves

## 6. Hands-on labs (`labs/`)

- [x] 6.1 Write `labs/README.md` catalog: table mapping each subsection (tracker id) → lab(s) → type → OSS component(s)
- [x] 6.2 Author domain-1 labs (Keycloak SSO/MFA, K8s RBAC, PIM/JIT, Kyverno/Gatekeeper admission) in the standard format with concrete verification
- [x] 6.3 Author domain-2 labs (Vault dynamic secrets, cert-manager, NetworkPolicy default-deny, WAF blocking)
- [x] 6.4 Author domain-3 labs (pod security, Falco/Tetragon detection, Trivy/Grype supply-chain, Ollama prompt-injection + guardrails)
- [x] 6.5 Author domain-4 labs (Prometheus/Grafana/Loki alerting, Wazuh detection + active response, Suricata/Zeek, Kubescape compliance scan)
- [x] 6.6 Each lab names its SC-500 control correspondence; mark infeasible-locally topics `walkthrough`; verify every subsection maps to ≥1 lab

## 7. Assessment quizzes

- [x] 7.1 Author `assessment/data/quiz-1.yaml` … `quiz-4.yaml` (≥25 scenario questions each, OSS-framed, `objectiveIds` resolving to tracker, `docUrl`, zero-based `answer`, ≥2 options) in study-hub's quiz shape
- [x] 7.2 Regenerate `assessment/checkpoint-1..4.md` via `scripts/gen-md.mjs`
- [x] 7.3 Write `assessment/readiness.md`: checkpoint target, capstone requirement, miss→tracker remediation loop

## 8. study-hub integration

- [x] 8.1 Add oss-500 as a submodule at `content/oss-500` in `../study-hub/.gitmodules`
- [x] 8.2 Write `../study-hub/src/content/adapters/oss500.ts`, derived from `scc500.ts`, with `CourseConfig` `id: "oss-500"`, `label`, `tagline`, `weekPaced: false`, no `specialRefs`
- [x] 8.3 Add the `{ id: 'oss-500', adapter: oss500Adapter }` line to `../study-hub/src/content/registry.ts`
- [x] 8.4 Following scc-500's `terraform/*/README.md` model, add a `content/*/lab-infra/*/README.md` glob to `../study-hub/src/content/raw.ts` and have the `oss500` adapter ingest lab-infra READMEs as browsable in-app docs (the terraformDocs equivalent) and valid link targets for `lab-infra/` references
- [x] 8.5 Run `../study-hub` `npm run lint:content` and `npm test` green with oss-500 present; verify the course renders and routes under `/oss-500/*`

## 9. Integration & verification

- [ ] 9.1 Full-stack capstone: bring up the integrated lab environment end to end and validate cross-tool flow (identity → workload → detection → SIEM)
- [x] 9.2 Confirm oss-500 content renders in study-hub (dashboard, plan, notes, labs, tracker, quizzes) with no trial-clock widgets
- [x] 9.3 Secrets scan of committed oss-500 content passes (no tokens, keys, or identifiers)
- [x] 9.4 Final coverage check: every SC-500 objective has notes + a lab (hands-on or walkthrough) + a checkpoint question
