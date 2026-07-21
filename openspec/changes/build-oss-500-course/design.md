## Context

`../scc-500` is a mature SC-500 study system: a YAML-source → generated-markdown → React-UI pipeline with Terraform provisioning Azure labs, budgeted around Azure credit and expiring trials. OSS-500 rebuilds the *curriculum* to teach the same concepts on a 100% open-source, locally-runnable stack.

The decisive context: **the rendering app already exists and is course-agnostic.** `../study-hub` was ported from `scc-500/ui` and generalized so that every course's content is normalized on load into one shared model (`src/content/model.ts`) and rendered by the same UI (dashboard, plan, notes, labs, tracker, quizzes, cross-linking, search). Courses are consumed as git submodules under `content/`, and each is reconciled by a thin adapter in `src/content/adapters/*`; adding a course is "one adapter + one registry line." scc-500, tf-004, and modern-security-lab are already wired in. Building another UI in oss-500 would re-create exactly the redundancy study-hub eliminates.

So oss-500 is a **pure-content course repo**. The design work is entirely in the three things that are genuinely OSS-specific — the curriculum mapping, the labs, and the local lab infrastructure that replaces Terraform+Azure — plus a thin integration into study-hub.

**Constraints:** run on a laptop-class host for $0; no cloud account or trials; preserve SC-500 concept coverage so skills transfer to the exam; conform to study-hub's content contract so no per-course UI is needed; keep portfolio hygiene and lint-in-CI (study-hub's `lint:content`).

## Goals / Non-Goals

**Goals:**
- Full concept parity with the SC-500 skills outline, taught through OSS tools, with the four SC-500 domains and weights as the curriculum spine.
- A reproducible, idempotent, single-host lab stack (kind + Helm/manifests + Docker Compose) with a deploy→verify→destroy loop per lab.
- Content authored to study-hub's shared model so its existing dashboard, tracker, quiz runner, and cross-linking render oss-500 unmodified.
- $0 software cost; portfolio-quality public repo.

**Non-Goals:**
- **No study app in oss-500.** No `ui/`, no ported rendering/tracking/quiz code. study-hub owns all of that.
- Not an exam-dump or a Microsoft-product tutorial; SC-500 is the concept map, not the toolset.
- Not a multi-node/production cluster — labs target a single host; genuinely multi-node topics are `walkthrough`.
- Not porting the cloud cost/trial-timeline machinery — replaced by a local-resource model and suppressed in the UI via `weekPaced: false`.
- Not reusing Terraform+Azure providers; Azure IaC is out of scope.

## Decisions

**D1 — Keep the four SC-500 domains as the spine; fold the 9 OSS tool areas into them.** Mapping the starting-point doc's 9 areas under the four SC-500 domains keeps weights and concept coverage faithful:
- `1-identity-governance` — Keycloak/Authentik SSO+MFA, Kubernetes RBAC, Teleport/Boundary PIM, workload identity; OPA/Kyverno/Gatekeeper + Kubescape governance.
- `2-secrets-data-networking` — Vault (secrets, dynamic creds, HSM), cert-manager; NetworkPolicy, service mesh/zero-trust, ModSecurity/NGINX WAF, OPNsense/pfSense concepts.
- `3-compute-ai` — pod security, admission control, Falco/Tetragon runtime, Trivy/Grype supply chain; Ollama/Open WebUI + NeMo Guardrails AI security.
- `4-posture-monitoring` — Prometheus/Grafana/Loki/Tempo/OpenTelemetry observability; Wazuh + OpenSearch + Suricata + Zeek + Sigma SIEM/IR; Trivy/Grype/Kubescape vuln management.
*Alternative — 9 flat domains mirroring the source doc:* rejected; it breaks weight calibration and the "aligns with SC-500" promise.

**D2 — Replace Terraform+Azure with kind + Helm/manifests + Docker Compose.** In-cluster components deploy to a local **kind** cluster (chosen for zero external footprint, fast create/destroy, and being the natural CI/ephemeral target — it doubles as the reference for teardown discipline). Host-level appliances (Wazuh, OpenSearch, Suricata, Zeek) run via Docker Compose. Each lab brings up only what it needs. *Alternatives:* k3s — viable but heavier and less ephemeral than kind for a laptop; one giant compose stack — rejected as too heavy and it defeats deploy→verify→destroy; a Terraform layer over local k8s — rejected as friction, raw manifests + Helm values read better as study material.

**D3 — oss-500 is content-only; integrate via a thin study-hub adapter.** Rather than port a UI, author content in study-hub's ingestion layout (`plan/*.md`, `domains/**/*.md`, `labs/*.md`, `assessment/data/*.yaml`) and mirror scc-500's data shapes (nested `domains → subsections → objectives`, `tracker.yaml`, `quiz-*.yaml`, `**[Nh]**` plan blocks) so the new `oss500` adapter is derived from `scc500.ts` with minimal change. Wire it in with one `.gitmodules` submodule + one `registry.ts` line. *Rationale:* the shared app is the largest reusable asset and is explicitly designed for exactly this ("one adapter + one registry line").

**D4 — Suppress trial/cost widgets via config, don't build a new panel.** `CourseConfig.weekPaced` gates study-hub's dashboard trial-clock and week-schedule widgets. Setting `weekPaced: false` for oss-500 makes the Azure cost/trial UI simply not render — no new "lab-environment status" panel is needed. (An optional future enhancement could add a lab-readiness widget to study-hub, but it is out of scope here.)

**D5 — Concept-mapping is a first-class content requirement.** Every objective's notes and every lab explicitly name the SC-500 technology, the OSS equivalent, and the transferable concept, and every lab's verification proves the OSS control enforces the same security outcome as the Azure control. This is what makes OSS-500 an SC-500 study aid rather than just a homelab.

**D6 — Build order follows the dependency graph, content-first.** `tracker.yaml` first (it defines the objective-id namespace everything joins on), then curriculum + labs + lab-infra per domain, then quizzes, then the study-hub adapter + registration, then portfolio polish. study-hub's `lint:content` gates correctness from early on (via the submodule pointer).

## Risks / Trade-offs

- **Scope is large (curriculum + labs + infra).** → Sequence by domain; the tracker + study-hub lint make partial coverage visible, and study-hub tolerates missing content by design (labeled empty states, `tracker: null` doc-only mode as a fallback).
- **Concept mapping can become superficial ("tool X ≈ tool Y").** → Require each lab's verification to prove the equivalent security *outcome*, not just deploy the tool; require notes to state the concept, not just the mapping.
- **Single-host resource pressure** (Wazuh+OpenSearch+full observability+kind is heavy). → Per-lab bring-up/teardown, documented footprints, phase-scoped stacks so components aren't all up at once; mark genuinely infeasible topics `walkthrough`.
- **Content-contract drift from study-hub** (shape changes break the adapter). → Mirror scc-500's shapes closely and rely on study-hub's `lint:content` + adapter tests in CI to catch drift at pointer-bump time.
- **Adapter/registry edits live in a different repo** than this change's scope. → Treated as an explicit `study-hub-integration` capability; those files (`.gitmodules`, `registry.ts`, `adapters/oss500.ts`) are additive and validated by study-hub's own suite.
- **OSS tools move fast; pinned versions rot.** → Pin chart/image versions in `lab-infra/`, document tested versions, treat upgrades as their own maintenance task.
- **Not 1:1 with every Azure feature** (Security Copilot, Purview DSPM). → Teach the underlying concept with the nearest OSS analog, mark the gap explicitly, use `walkthrough` where no faithful local analog exists.

## Migration Plan

Greenfield — no existing system to migrate. Build the oss-500 tree incrementally, commit it, then add it to study-hub as a submodule + adapter + registry line and bump the pointer. Keep study-hub green via its `lint:content` and tests at each pointer bump. No rollback concern; each capability is additive and study-hub degrades gracefully over absent content. Optionally add a `content/*/lab-infra/*/README.md` glob to `study-hub/src/content/raw.ts` if lab-infra READMEs should be browsable in-app.

## Resolved Decisions (previously open)

The guiding rule where a choice existed: **follow the scc-500 model.**

- **Adapter:** fork a thin `oss500.ts` derived from `scc500.ts` with `weekPaced: false` and no `specialRefs` (do not reuse `scc500Adapter` directly).
- **Lab-infra READMEs:** browsable in-app, mirroring scc-500's `terraform/*/README.md` ingestion — add a `content/*/lab-infra/*/README.md` glob to `study-hub/src/content/raw.ts` and surface them via the adapter as docs and link targets. Each `lab-infra/<component>/` therefore carries its own README, like scc-500's per-lab terraform roots.
- **Generated markdown views:** commit `assessment/tracker.md` and `checkpoint-*.md`, regenerated by a small standalone `scripts/gen-md.mjs` in oss-500 (no app dependency) — the same generate-from-YAML pattern scc-500 uses.
