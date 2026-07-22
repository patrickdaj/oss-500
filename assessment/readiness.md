# Readiness gate

OSS-500 has no proctored exam — the gate is your own honest bar for "I can engineer these controls." Declare readiness only when all three conditions hold. Every miss maps back to a tracker objective so remediation is targeted, not vague.

## The gate

1. **Coverage** — every objective in [`tracker.yaml`](data/tracker.yaml) has: notes read, its lab performed (or its walkthrough section studied at depth), and self-rated confidence ≥ 2 of 3. Filter the tracker in study-hub for confidence 1 or missing labs; that list is your remaining work.
2. **Checkpoints** — each of the six checkpoint banks scored **≥ 85% on two consecutive attempts** in test mode. One good score can be luck; two in a row is retention.
   - [checkpoint-1](checkpoint-1.md) — Identity, access, governance
   - [checkpoint-2](checkpoint-2.md) — Secrets, data, networking
   - [checkpoint-3](checkpoint-3.md) — Compute and AI security
   - [checkpoint-4](checkpoint-4.md) — Manage and monitor posture
   - [checkpoint-5](checkpoint-5.md) — Prove it: offensive validation *(beyond-blueprint)*
   - [checkpoint-6](checkpoint-6.md) — Agentic zero trust *(beyond-blueprint)*
3. **Capstone** — the full-stack capstone in [`plan/review.md`](../plan/review.md) stands up end to end and you can demonstrate the **identity → workload → detection → SIEM** chain (Keycloak OIDC + MFA → Vault dynamic secret via workload identity → Kyverno/Gatekeeper admission block → Falco alert → Wazuh detection + active response) and have written it up.

## Remediation loop

When a checkpoint attempt scores below 85%:

1. In study-hub, every missed question exposes its `objectiveIds`. The missed questions feed the review queue automatically.
2. For each missed objective: re-read its notes section, re-run its lab (prove the control again — don't just re-read), then run the review-queue session until those questions are answered correctly.
3. Re-attempt the full checkpoint in test mode. Repeat until you clear ≥ 85% twice consecutively.

Confidence is the leading indicator: an objective marked confidence 1 is a remediation target even if its checkpoint questions happened to land correctly.

## Attempt log

Track attempts here (or in study-hub's attempt history, which is the source of truth):

| # | Date | Checkpoint | Score | Mode | Gate progress |
|---|---|---|---|---|---|
|   |      |            |       | test |               |

## What "ready" means here

Passing this gate means you can, on open-source tooling and from a clean clone, stand up and *prove* the security controls the SC-500 exam tests as concepts: SSO/MFA/conditional access, just-in-time privileged access, least-privilege RBAC, dynamic secrets and certificate lifecycle, default-deny segmentation and WAF, pod hardening and admission control, supply-chain scanning and signing, AI-workload guardrails, runtime detection, SIEM detection-as-code, and posture/compliance reporting. That skill set transfers directly to the Azure controls SC-500 names — and to AWS, GCP, and on-prem.
