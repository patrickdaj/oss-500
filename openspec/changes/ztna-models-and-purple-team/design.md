# Design: ztna-models-and-purple-team

## Context

oss-500 is a content-only course repo ingested by study-hub; markdown views are generated from YAML by `scripts/gen-md.mjs`. It already has a full tracker/quizzes/plan and 4 SC-500-mapped domains, plus reproducible local `lab-infra/` (kind + Helm/compose). This change adds content + lab-infra, not tooling changes.

## Decisions

### D1 — SC-500 is the anchor; the course identity expands around it
Domains 1–4 keep their SC-500 objective mapping (the defensive spine, the exam value). The new ZTNA models and purple-team work are **beyond-blueprint enrichment**, marked as such so a learner using this for SC-500 can see what's exam vs. what's the expanded flagship. The README thesis becomes "Expanded Cloud & AI Security for OSS — defense and offense," with SC-500 as the anchor.

### D2 — ZTNA "five models" live in Domain 1 (Identity & Access)
The access models are an *access* concern, so they extend Domain 1 alongside Teleport PAM (network-layer ZT — NetworkPolicy/mesh — stays in Domain 2). New: Boundary+Vault (broker + injection), OpenZiti (overlay), Pomerium (id-aware proxy), Netbird (WireGuard mesh). Framed as one taxonomy (broker · overlay · proxy · mesh · workload-identity substrate = SPIFFE). The goal is **adequate, correct coverage of each model** — no cross-model comparison artifact (dropped per scope). Vendor Prisma/Cloudflare are not built and not compared; they may be named in passing at most.

### D3 — Purple-team as a capstone domain + per-lab "validate it" callouts
A new **Domain 5 — "Prove It: Offensive Validation"** (beyond-blueprint, recommended capstone): red-team the defenses built in D1–D4. Frameworks: **MITRE ATT&CK** for infra, **MITRE ATLAS + OWASP LLM Top 10** for AI. Three tracks — AI (garak/PyRIT/PortSwigger vs the NeMo-Guardrails gateway), infra (Atomic Red Team/Caldera/Stratus vs Falco/Tetragon/Suricata/Wazuh), ZTNA (unauthorized-access attempts vs the brokers). Plus a lightweight **"validate it"** callout appended to relevant existing D1–D4 labs so validation is felt throughout, not just at the end.

### D4 — Retire modern-security-lab; migrate OSS, keep vendor as contrast
The OSS notes/labs from `modern-security-lab` (Boundary+Vault, OpenZiti, garak/PyRIT/PortSwigger, NIST 800-207/ZTNA framing) migrate into oss-500's D1/D5. `modern-security-lab` is reduced to a **portfolio artifact** — the veteran→modern narrative + the ZTNA comparison (which needs Prisma/Cloudflare for contrast) — that links to oss-500's labs rather than duplicating them. The garak-vs-Ollama run already executed in modern is reused as real evidence.

### D5 — lab-infra additions stay "$0, local, reproducible", Terraform-automated
Each new tool gets a `lab-infra/<tool>/` like the rest. The control-plane containers come up via the existing kind + Helm/compose pattern; **resource/policy config is Terraform-automated wherever a provider exists** — Boundary, Vault (both have mature providers), Netbird (official provider), OpenZiti (community edge provider) — so the ZTNA labs are genuinely as-code, not console clicks. Pomerium is config-file/Helm (TF wraps the Helm release). Offensive tooling (garak/PyRIT via pip/pipx; Atomic Red Team, Caldera, Stratus) runs against the *local* stack only — never external targets — with documented teardown.

### D8 — Netbird for the WireGuard-mesh model (Terraform-driven)
**Netbird** over Headscale: it's fully OSS *including* the control plane (self-hostable, $0/local) **and** has an official Terraform provider for peers/groups/access-policies/setup-keys — so it satisfies the "supported by TF automated deployments" bar. Headscale is config-file-driven with no TF provider, so it loses on the as-code criterion. Tailscale's own TF provider targets its proprietary SaaS, which breaks the no-account thesis.

### D6 — Frameworks tie it together
The purple-team spine is the mapping: every defensive control cites the ATT&CK/ATLAS technique that validates it, so the course reads as "build the control → name the technique → fire it → confirm detection." This is also what makes it portfolio-grade (purple-team, not just blue).

### D7 — A standards spine, offense ↔ defense
Standards are first-class, not decoration. Each control cites its **defensive** standard and each validation its **offensive** one, paired:
- **Infra:** MITRE **ATT&CK** (attack technique) ↔ MITRE **D3FEND** (defensive technique) — the cleanest offense/defense pairing; CIS Benchmarks for hardening, NIST **CSF 2.0** as the governance umbrella.
- **AI:** **OWASP LLM Top 10** (risk) + MITRE **ATLAS** (technique) + NIST **AI RMF** (governance function).
- **Zero trust:** NIST **SP 800-207 / 207A** (definition) + **CISA ZTMM** (maturity).
- **Anchor:** the existing **SC-500** objective mapping stays as the exam spine.

The mapping is authored into the domain notes and carried in the tracker (a `standards:` field per objective where useful), so it renders in study-hub and reads as standards-grounded. Only real, verified standard references — no invented control IDs.

## Risks / tradeoffs

- **Scope:** this is large — phase it (ZTNA models first; purple-team second; migration/retire last) so each phase is shippable and study-hub stays green throughout.
- **Blueprint dilution:** mitigated by explicit "beyond-blueprint" marking and keeping D1–D4 objectives intact.
- **Offensive-tool executability:** garak runs locally (proven); Caldera/Atomic need the lab stack up — mark honestly what's executed vs. directions, same discipline as modern (no fabricated results).

## Resolved
- **WireGuard-mesh tool → Netbird** (fully OSS + official Terraform provider; see D8).
- **No comparison artifact** — the bar is adequate, correct per-model coverage, not a contrast piece.
- **All ZTNA labs Terraform-automated** where a provider exists (D5).
