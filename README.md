# OSS-500 — Open-Source Cloud & AI Security Engineering

A complete, self-built study system that teaches the concepts of Microsoft exam **SC-500 (Cloud and AI Security Engineer Associate)** on a **100% open-source stack** — for **$0**, entirely on a local machine, with no cloud account and no expiring trials.

Every SC-500 control is mapped to an open-source equivalent and practiced as a hands-on lab you deploy, verify, and tear down. The skills transfer across Azure, AWS, GCP, and on-prem — because you learn the *concept* (just-in-time privileged access, default-deny segmentation, admission control, runtime detection, SIEM detection-as-code) through a portable tool, not a vendor console.

> **This is a content-only course repo.** The study app is [`study-hub`](../study-hub) — a course-agnostic dashboard/notes/labs/tracker/quiz runner that ingests this repo as a git submodule. There is no `ui/` here by design.

## What it demonstrates

- **Identity & access** — Keycloak SSO/MFA/federation, Kubernetes RBAC, just-in-time privileged access (Teleport/Boundary), workload identity.
- **Secrets, data & networking** — HashiCorp Vault (dynamic secrets, rotation, transit), cert-manager, default-deny NetworkPolicy, service-mesh mTLS, ModSecurity WAF, data-at-rest encryption.
- **Compute & AI** — Pod Security Admission, Kyverno/OPA Gatekeeper admission control, Falco/Tetragon runtime detection, Trivy/Grype/Harbor supply chain, and **AI security** (model access control, prompt-injection guardrails, secure RAG, LLM observability).
- **Posture & monitoring** — Prometheus/Grafana/Loki/Tempo observability, Wazuh + OpenSearch SIEM, Suricata/Zeek network detection, Kubescape posture & compliance.
- **Policy-as-code & IaC** — the whole lab stack is deployed as annotated Helm values / Kubernetes manifests that double as study material.

## SC-500 concept mapping

The four SC-500 domains and their exam weights are the spine of the curriculum:

| Domain | Weight | Open-source coverage |
|---|---|---|
| 1 — Identity, access, governance | 20–25% | Keycloak · K8s RBAC · Teleport/Boundary · OPA/Kyverno · Kubescape |
| 2 — Secrets, data, networking | 25–30% | Vault · cert-manager · NetworkPolicy · service mesh · ModSecurity WAF |
| 3 — Compute & AI security | 20–25% | Pod security · Falco/Tetragon · Trivy/Grype · Ollama + guardrails |
| 4 — Posture & monitoring | 20–25% | Prometheus/Grafana/Loki · Wazuh · Suricata/Zeek · Kubescape |

Full objective-by-objective coverage is in [`assessment/tracker.md`](assessment/tracker.md) (generated from [`assessment/data/tracker.yaml`](assessment/data/tracker.yaml)).

## Repo layout

```
plan/         Phased learning path — fundamentals ramp, four domain phases, review + capstone
domains/      Study notes: one file per objective subsection, mapping SC-500 concept → OSS tool
labs/         Lab catalog + hands-on lab guides (objectives, steps, verification, teardown)
lab-infra/    Reproducible local lab stack as code (kind + Helm/manifests + Docker Compose)
assessment/   Objective tracker + per-domain checkpoint quizzes + readiness gate (YAML source in data/)
scripts/      gen-md.mjs — regenerate the markdown views from the YAML
```

## Using this repo

1. **Prerequisites**: Docker, [kind](https://kind.sigs.k8s.io/), `kubectl`, and [Helm](https://helm.sh/). A laptop-class host with ~16 GB RAM runs every hands-on lab (bring components up per lab, tear down after).
2. **Start with the plan**: [`plan/overview.md`](plan/overview.md) explains the phased path; [`plan/phase0-fundamentals.md`](plan/phase0-fundamentals.md) is day one.
3. **Run a lab**: each `lab-infra/<component>/` is self-contained —
   ```bash
   cd lab-infra/identity           # bring up Keycloak on the kind cluster
   ./up.sh                          # deploy
   # ...do the lab in labs/, verify the control works...
   ./down.sh                        # tear down — no orphaned resources
   ```
4. **Track progress**: open this course in `study-hub` (course switcher → OSS-500). Progress lives in the browser.

## Rendering & tracking (study-hub)

```bash
cd ../study-hub
git submodule update --init content/oss-500
npm install && npm run dev          # pick "OSS-500" from the course switcher
```

`study-hub` renders `plan/`, `domains/`, `labs/`, and `assessment/data/` and provides the dashboard, interactive tracker, and quiz runner. To regenerate the readable markdown views in this repo after editing YAML:

```bash
npm install        # first time (js-yaml)
npm run gen:md     # regenerates assessment/tracker.md + checkpoint-*.md
```

## Secrets hygiene

No tokens, kubeconfigs, Vault unseal keys, or TLS private keys are committed. Local values enter only through gitignored files (see the `*.example` templates). This repo is a public-portfolio work sample: everything is reproducible from a clean clone.
