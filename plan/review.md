# Review & capstone

The final phase consolidates the four domains, runs an end-to-end capstone that integrates the whole stack, and applies the readiness gate before you call yourself SC-500-ready on open-source terms.

## Day 1 — Re-take checkpoints and find gaps

- [ ] **[3h] Re-run all four checkpoints in test mode** — [checkpoint 1](../assessment/checkpoint-1.md)–[4](../assessment/checkpoint-4.md) via study-hub. Record scores.
- [ ] **[2h] Remediation triage** — every missed question maps to `objectiveIds`; open those tracker rows, re-read the notes, and re-run the specific lab. See [readiness.md](../assessment/readiness.md).
- [ ] **[1h] Confidence sweep** — filter the tracker for confidence 1 and missing labs; list them as the week's targets.

## Day 2–3 — Full-stack capstone

Bring the whole environment up at once and prove a cross-tool security flow end to end. This is the integration milestone.

- [ ] **[3h] Stand up the integrated stack** — kind cluster + Keycloak (identity) + Vault (secrets) + Kyverno/Gatekeeper (admission) + Falco/Tetragon (runtime) + Wazuh/OpenSearch (SIEM) + Prometheus/Grafana/Loki (observability). Bring components up in dependency order; watch the resource budget.
- [ ] **[3h] Prove the identity → workload → detection → SIEM chain**:
  - A user authenticates to a protected app via **Keycloak** (OIDC), MFA enforced.
  - The workload pulls a **Vault** dynamic secret via its ServiceAccount (workload identity).
  - **Kyverno/Gatekeeper** blocks a deliberately non-compliant deployment at admission.
  - A shell in a running pod triggers a **Falco** rule; the alert ships to **Wazuh**.
  - You **hunt** the event in OpenSearch and trigger a Wazuh **active response**.
- [ ] **[2h] Write it up** — a short incident narrative tying each step to the SC-500 domain it evidences. This is the portfolio centerpiece.

## Day 4 — Posture, compliance, and teardown

- [ ] **[2h] Cluster posture & compliance** — run **Kubescape** against the full stack, generate a compliance report, remediate the top findings, re-scan.
- [ ] **[1.5h] Supply-chain sweep** — **Trivy** every image in use; confirm admission gating rejects a known-vulnerable image.
- [ ] **[1h] Clean teardown** — `down.sh` every component, `kind delete cluster`, confirm no leftovers.

## Readiness gate

Declare readiness only when all of the following hold (see [readiness.md](../assessment/readiness.md)):

1. Every tracker objective has notes read, its lab performed (or walkthrough studied), and confidence ≥ 2.
2. All four checkpoints scored **≥ 85%** on two consecutive attempts.
3. The full-stack capstone stands up and every step of the identity → workload → detection → SIEM chain is demonstrated and written up.
