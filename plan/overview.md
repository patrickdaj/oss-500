# OSS-500 Study Plan — Overview

A phased path that teaches the SC-500 (Cloud & AI Security Engineer) concepts on a 100% open-source stack. Six phases: a fundamentals ramp, four domain phases weighted by their SC-500 exam percentages, and a review/capstone phase. Everything runs locally on a laptop-class host for **$0** — no cloud account, no expiring trials.

## Phase map

| Phase | Focus | Exam weight | Milestone (end of phase) |
|---|---|---|---|
| [0](phase0-fundamentals.md) | Linux, containers, Kubernetes, kind + IaC ramp | — | Can build/inspect a kind cluster, images, RBAC, Helm releases |
| [1](phase1-identity-governance.md) | Identity, access, governance | 20–25% | Domain 1 objectives green; checkpoint 1 ≥ 80% |
| [2](phase2-secrets-data-networking.md) | Secrets, data, networking | 25–30% | Domain 2 objectives green; checkpoint 2 ≥ 80% |
| [3](phase3-compute-ai.md) | Compute & AI security | 20–25% | Domain 3 objectives green; checkpoint 3 ≥ 80% |
| [4](phase4-posture-monitoring.md) | Posture, SIEM, monitoring | 20–25% | Domain 4 objectives green; checkpoint 4 ≥ 80% |
| [R](review.md) | Review, capstone, readiness | — | Full-stack capstone stands up; checkpoints ≥ 85% |

Phase 2 (secrets/data/networking, 25–30% — the heaviest SC-500 domain) gets the most days, mirroring the exam weighting.

## Day structure

Each study day is a set of time-boxed blocks alternating **input** (docs, videos, reading) and **output** (labs, notes, quiz questions). Convention used in every phase file — study-hub parses these into checkable blocks:

- `## Day N — <focus>` headings; blocks are task-list items: `- [ ] **[2h] <block>** — details`
- **The last day of each phase is flex**: catch-up, weak-spot review, and the phase's checkpoint quiz. Slippage lands here, never in the next phase.
- **Take a day off each week.** Sustained intensity without rest fails.
- End every lab block with the component's `./down.sh` (or `kind delete cluster`). Leftover containers are the #1 resource killer on a laptop.

If a checkpoint scores < 80%, the following flex day goes to remediation of the missed objectives (the tracker shows them) before new material.

## Local resource readiness

There is no cloud cost or trial timeline — instead, plan host resources. Baseline reference host: **~4 CPU cores, 16 GB RAM, 40 GB free disk.**

| Phase | Bring up | Approx. footprint | Tear down after |
|---|---|---|---|
| 0 | kind cluster only | ~2 GB | keep (reused everywhere) |
| 1 | Keycloak, Kyverno/Gatekeeper, Kubescape | ~3–4 GB | Keycloak after identity labs |
| 2 | Vault, cert-manager, ingress + WAF, a mesh | ~4–5 GB | mesh/WAF after their labs |
| 3 | Falco, Tetragon, Trivy, Harbor, Ollama | ~5–6 GB | Harbor/Ollama after their labs |
| 4 | Prometheus/Grafana/Loki, Wazuh+OpenSearch, Suricata/Zeek | ~6–8 GB | the whole stack after the phase |

Bring up **only what the current lab needs**; the labs and `lab-infra/` READMEs document per-component `up.sh`/`down.sh`. Wazuh + OpenSearch (Phase 4) and the full observability stack are the heaviest — run them alone. Anything that won't fit the reference host is marked `walkthrough` in the tracker.

## Where things live

- **Notes** per objective subsection: [`domains/`](../domains/) (files named in each phase plan)
- **Labs**: [`labs/README.md`](../labs/README.md) is the catalog; lab environments are in [`lab-infra/`](../lab-infra/)
- **Progress**: [`assessment/data/tracker.yaml`](../assessment/data/tracker.yaml) (70 objectives) — tracked interactively in study-hub
- **Checkpoints**: quiz banks in `assessment/data/`, one per domain, taken on each phase's flex day
- **Readiness**: [`assessment/readiness.md`](../assessment/readiness.md) — the checkpoint target, capstone, and remediation loop

## Rules that keep this on track

1. **Output over input**: never more than ~90 minutes of reading/video without deploying, breaking, or quizzing something.
2. **The tracker is the truth**: an objective isn't done until notes are read, its lab performed (or walkthrough studied), and its checkpoint questions passed.
3. **Teardown before shutdown**: no lab component survives overnight unless the next morning's first block continues it. `kind delete cluster` is the ultimate reset.
4. **Prove the control, don't just deploy the tool**: every lab has a verification step where the security control provably denies, alerts, or blocks. Deploying Falco isn't done until you've *triggered* a Falco alert.
