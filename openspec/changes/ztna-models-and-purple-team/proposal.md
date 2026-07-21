# Proposal: ztna-models-and-purple-team

## Why

oss-500 is already a remarkably complete **defensive** open-source security course mirrored to SC-500. Its one gap isn't a missing control — it's two missing *dimensions*: it never completes the **zero-trust access-model** picture (it has Teleport PAM + NetworkPolicy/mesh, but not the broker/overlay/proxy/mesh ZTNA archetypes), and it never **proves its defenses work** (every lab ends at "deployed," never "attacked and caught").

This change expands oss-500 from an SC-500 mirror into an **expanded Cloud & AI Security course for OSS** — defense *and* offense, 100% open-source, $0, local. SC-500 stays the defensive **anchor** (Domains 1–4 keep their objective mapping); the new content is explicitly beyond-blueprint enrichment. It also absorbs the OSS pieces from the sibling `modern-security-lab` course, retiring that as a standalone (its vendor pieces — Prisma Access, Cloudflare — become named *contrast*, not built, since they break the "no cloud account" thesis).

## What Changes

- **Complete the ZTNA access-model taxonomy** — five models, one principle, **Terraform-automated**:
  Teleport (broker, ✅ have) · **Boundary + Vault** (broker + credential injection) · **OpenZiti** (app-embedded overlay, zero listening ports) · **Pomerium** (identity-aware reverse proxy / BeyondCorp) · **Netbird** (WireGuard mesh — the OSS Tailscale, chosen for its self-hostable control plane *and* official Terraform provider). SPIFFE/SPIRE (✅ have) is the workload-identity substrate. The bar is adequate, correct coverage of each model — no cross-model comparison artifact.
- **Add a purple-team validation dimension** — prove every control by attacking it:
  **AI** — garak / PyRIT / PortSwigger red-team the NeMo-Guardrails gateway oss-500 builds (mapped to OWASP LLM Top 10 / MITRE ATLAS). **Infra** — Atomic Red Team / Caldera / Stratus Red Team fire real MITRE ATT&CK techniques at the Falco/Tetragon/Suricata/Wazuh detection stack to confirm alerts fire. **ZTNA** — attempt unauthorized access to prove least-privilege holds. A capstone domain plus lightweight "validate it" callouts in existing labs.
- **Absorb `modern-security-lab`** — migrate its OSS notes/labs (Boundary, OpenZiti, garak/PyRIT, the ZTNA/800-207 framing) into oss-500; reduce modern to a portfolio artifact (the veteran→modern narrative + the vendor comparison) that references oss-500's labs.
- **Fold in the standards as an explicit spine** — every control maps to a *defensive* standard and every validation to an *offensive* one: **MITRE ATT&CK** ↔ **MITRE D3FEND** (infra offense/defense), **MITRE ATLAS** + **OWASP LLM Top 10** + **NIST AI RMF** (AI), **NIST SP 800-207/207A** + **CISA ZTMM** (zero trust), **CIS Benchmarks** + **NIST CSF 2.0** (posture/governance). The mapping is authored into notes and the tracker, so the course reads as standards-grounded, not tool-driven.
- **Reframe the course identity** — README/thesis: "Expanded Cloud & AI Security, OSS — defense and offense, standards-grounded," with SC-500 as the defensive anchor and the new material marked beyond-blueprint.

## Non-Goals

- No vendor/SaaS labs (Prisma, Cloudflare, hosted Tailscale) — they break the $0/local/no-account thesis; they appear only as *contrast* in the ZTNA comparison.
- Don't dilute the SC-500 spine: Domains 1–4 keep their objective→control mapping; offense is additive, clearly marked beyond-blueprint.
- No study-hub code changes — oss-500 already ingests cleanly (full tracker/quizzes/plan); new domains/labs flow through the existing `gen-md` pipeline.
