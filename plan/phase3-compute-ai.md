# Phase 3 — Compute & AI security

Domain 3 is **20–25% of SC-500** and the milestone at the end of this phase is: Domain 3 objectives green, checkpoint 3 ≥ 80%. This phase secures the workload itself — hardening pods, catching runtime threats, locking down the software supply chain — and then the material Microsoft added to make this the *Cloud & AI Security Engineer* exam: **securing AI workloads** (new to SC-500, so lean on the notes and primary sources, not third-party cram decks).

Bring up only the component each day needs (Phase 3 footprint ≈ 5–6 GB): Falco/Tetragon, Harbor, and Ollama are the heavy hitters — don't run them all at once. Every lab ends with its `./down.sh`. The last day is flex + the checkpoint.

Notes: [pod-security](../domains/3-compute-ai/pod-security.md) · [runtime-security](../domains/3-compute-ai/runtime-security.md) · [supply-chain](../domains/3-compute-ai/supply-chain.md) · [ai-security](../domains/3-compute-ai/ai-security.md).

## Day 1 — Pod hardening and admission enforcement

- [ ] **[2h] Pod Security Standards + PSA** — read [pod-security.md](../domains/3-compute-ai/pod-security.md) through `pod-psa`/`pod-securitycontext`. Know the three profiles (privileged/baseline/restricted), the three modes (enforce/warn/audit), and the `securityContext` hardening checklist cold.
- [ ] **[2h] Lab: pod hardening** — [d3-pod-security](../labs/d3-pod-security.md) Parts A–B: watch PSA reject a `--privileged` pod in `oss500-apps`, then run a hardened pod and prove `id -u`≠0 and a write to `/` returns read-only. `lab-infra/shared` is enough for these parts.
- [ ] **[1.5h] Admission engines** — finish the notes on `pod-admission`; `lab-infra/governance` up; lab Part C: a Kyverno ClusterPolicy rejecting an unapproved registry (the rule PSA can't express). Note Kyverno-vs-Gatekeeper and that Azure Policy for AKS *is* Gatekeeper.
- [ ] **[0.5h] Teardown + notes** — `cd lab-infra/governance && ./down.sh`; jot the PSA-vs-Kyverno boundary in your own words.

## Day 2 — Runtime threat detection and response

- [ ] **[2h] Falco + Tetragon concepts** — read [runtime-security.md](../domains/3-compute-ai/runtime-security.md). Detect-vs-enforce: Falco alerts on syscalls; Tetragon can `Sigkill` in-kernel. Why security tooling runs in the privileged `oss500-security` namespace.
- [ ] **[2h] Lab: trigger a Falco alert** — [d3-runtime-detection](../labs/d3-runtime-detection.md) Parts A–B: `lab-infra/runtime` up; `kubectl exec` into a pod and watch **Terminal shell in container** fire within seconds; see it fan out through Falcosidekick to the UI/Loki. This is the "prove the control" moment — a fired alert, not just an installed tool.
- [ ] **[1.5h] Enforcement + response** — lab Part C: apply the Tetragon `TracingPolicy` and watch `cat /etc/shadow` get killed in-kernel; review the Falco Talon terminate-on-shell rule (`rt-response`). Map each to Defender for Containers.
- [ ] **[0.5h] Teardown** — `cd lab-infra/runtime && ./down.sh`; confirm no leftover DaemonSets.

## Day 3 — Software supply chain: scan, sign, gate

- [ ] **[2h] Scanning + SBOMs** — read [supply-chain.md](../domains/3-compute-ai/supply-chain.md) through `sc-scan`/`sc-sbom`. Install the CLIs (`trivy grype syft cosign`). The gate is the exit code; SBOM formats are SPDX and CycloneDX; scan at build *and* continuously.
- [ ] **[2h] Lab: fail a build, build an SBOM** — [d3-supply-chain](../labs/d3-supply-chain.md) Parts A–B: `trivy image --exit-code 1` fails on a CRITICAL; generate an SBOM with Syft and scan it directly with Grype. No cluster component needed yet.
- [ ] **[2h] Registry, signing, admission gate** — `lab-infra/supplychain` (Harbor) up; lab Parts C–D: push + cosign-sign an image, then a Kyverno `verifyImages` policy that rejects the unsigned image and admits the signed one. Signing ≠ vuln-free — hold both ideas.
- [ ] **[0.5h] Teardown** — `cd lab-infra/supplychain && ./down.sh` (removes Harbor PVCs).

## Day 4 — AI security I: access, prompt injection, guardrails

- [ ] **[2h] AI threat model + OWASP LLM Top 10** — read [ai-security.md](../domains/3-compute-ai/ai-security.md) intro through `ai-guardrails`. LLM01 prompt injection (direct vs indirect), LLM02 disclosure, LLM06 excessive agency. This is new-to-SC-500 — expect real weight.
- [ ] **[2h] Lab: lock the model + block a jailbreak** — [d3-ai-security](../labs/d3-ai-security.md) Parts A–C: `lab-infra/ai` up (pulls `llama3.2:1b`); prove Ollama is ClusterIP-only and the gateway returns 401/429; then **send a jailbreak prompt and watch NeMo Guardrails refuse it** while a benign prompt is answered. That refusal is the headline observable.
- [ ] **[1.5h] Content-safety rails** — lab Part C output rail: seed a fake secret in context, ask the model to repeat it, watch the output rail block the leak (LLM02). Distinguish preventive guardrails from detective SOC alerting.
- [ ] **[0.5h] Notes** — write the direct-vs-indirect injection distinction and where each defense lives (user prompt vs data input).

## Day 5 — AI security II: secure RAG, observability, governance

- [ ] **[2h] Secure RAG** — read `ai-rag` and `ai-observability`. The #1 rule: retrieval must honor the user's permissions; per-tenant isolation; secrets in Vault; RAG is the top indirect-injection vector.
- [ ] **[2h] Lab: RAG isolation + observability** — [d3-ai-security](../labs/d3-ai-security.md) Parts D–E: two users, two knowledge bases — prove user B cannot get answers from user A's document; then inspect OpenTelemetry GenAI spans (token counts, `enduser.id`, `guardrail.blocked`) and watch blocked-jailbreak spans spike for the attacking identity.
- [ ] **[1.5h] AI governance (walkthrough)** — lab Part F: `opa eval` the gateway policy — deny an unsanctioned model, allow a sanctioned one; read how one central gateway controls shadow AI (Purview DSPM for AI analog). `ai-governance` is a walkthrough; study it at full depth.
- [ ] **[0.5h] Teardown** — `cd lab-infra/ai && ./down.sh` (keep the model PVC unless short on disk).

## Day 6 — Flex, weak-spot review, and checkpoint

- [ ] **[1.5h] Weak-spot remediation** — revisit any objective whose lab observable you didn't see cleanly (a jailbreak that wasn't blocked, a Kyverno policy that didn't reject). Re-run just that verification; the tracker shows what's still amber.
- [ ] **[1h] Cross-domain seams** — confirm you can articulate: Falco/guardrail alerts → Domain 4 SIEM; RAG secrets → Domain 2 Vault; model access → Domain 1 Keycloak/RBAC. Domain 3 doesn't stand alone.
- [ ] **[1.5h] Checkpoint 3** — take [quiz-3](../assessment/data/quiz-3.yaml) (`checkpoint-3`). Target ≥ 80%. Note every miss.
- [ ] **[flex] Catch-up / rest** — slippage from Days 1–5 lands here, never in Phase 4.

## Checkpoint

- **checkpoint-3** — [assessment/data/quiz-3.yaml](../assessment/data/quiz-3.yaml), 28 scenario questions across all four Domain 3 subsections (pod security, runtime, supply chain, AI security), pass ≥ 80%.
- If you score < 80%, the next phase's slack is *not* borrowed: spend the remainder of this flex day on the missed objectives (the tracker lists them) before starting Phase 4. AI-security misses especially — the material is new and unlikely to be reinforced elsewhere.
- **Milestone met when**: every `d3-*` objective is green in the tracker (notes read, lab performed or walkthrough studied, checkpoint questions passed).
