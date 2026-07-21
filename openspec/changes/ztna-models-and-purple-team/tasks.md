# Tasks: ztna-models-and-purple-team

Phased so each phase is shippable and study-hub stays green. Large change — expect multiple sessions. SC-500 anchor (D1–D4 objectives) stays intact throughout; new content is marked beyond-blueprint.

## 1. Scope, identity & standards spine

- [x] 1.1 Rework the README/thesis to "Expanded Cloud & AI Security for OSS — defense and offense, standards-grounded," with SC-500 as the defensive anchor and new material marked beyond-blueprint
- [x] 1.2 Establish the standards spine in the tracker: add a `standards:` field convention (defensive + offensive) and a short `domains/standards-map.md` note (ATT&CK↔D3FEND, ATLAS/OWASP-LLM/AI-RMF, 800-207/ZTMM, CIS/CSF) — verified links only
- [x] 1.3 ~~Decide the WireGuard-mesh tool + comparison home~~ — **Resolved:** Netbird (OSS + TF provider); **no comparison artifact** (adequate per-model coverage instead); all ZTNA labs Terraform-automated

- [x] 1.4 Enrich Phase-0 fundamentals notes with authoritative external sources (they had ~0 links)

## 2. ZTNA five models (Domain 1 extension) — Terraform-automated

- [x] 2.1 Note: ZTNA access-model taxonomy — broker / overlay / id-aware proxy / mesh / workload-identity, all to NIST 800-207; place Teleport (✅) and SPIFFE (✅) in it
- [x] 2.2 Lab: Boundary + Vault (broker + credential injection) — Terraform provider, reuse existing Vault infra; directions-first guide + CI-validated `lab-infra/ztna-boundary/` solution; **added oss-500 CI** (terraform fmt/validate + shellcheck)
- [ ] 2.3 Lab: OpenZiti (app-embedded overlay, zero listening ports) — Terraform edge provider
- [ ] 2.4 Lab: Pomerium (identity-aware reverse proxy / BeyondCorp) in front of an internal app — TF-wrapped Helm release
- [ ] 2.5 Lab: Netbird (WireGuard mesh with identity ACLs) — official Terraform provider

## 3. Purple-team: offensive validation (new Domain 5 + callouts)

- [ ] 3.1 Domain 5 notes: purple-team framing — build → name the technique → fire it → confirm detection; ATT&CK (infra) + ATLAS/OWASP-LLM (AI)
- [ ] 3.2 Lab (AI): garak/PyRIT/PortSwigger vs the D3 NeMo-Guardrails gateway; findings → OWASP LLM Top 10 + ATLAS (reuse the real garak-vs-Ollama evidence from modern)
- [ ] 3.3 Lab (infra): Atomic Red Team / Caldera / Stratus fire ATT&CK techniques at Falco/Tetragon/Suricata/Wazuh; confirm alerts fire (or document gaps)
- [ ] 3.4 Lab (ZTNA): unauthorized-access attempts prove least-privilege on the brokers
- [ ] 3.5 Add "validate it" callouts to the relevant existing D1–D4 labs (link the attack + technique that proves each control)

## 4. Migrate & retire modern-security-lab

- [ ] 4.1 Migrate the OSS notes/labs (Boundary+Vault, OpenZiti, garak/PyRIT/PortSwigger, 800-207/ZTNA framing) into oss-500's D1/D5; de-dupe against existing content
- [ ] 4.2 Reduce modern-security-lab to a portfolio artifact (veteran→modern narrative + ZTNA comparison referencing oss-500's labs); vendor pieces = contrast only
- [ ] 4.3 Archive the modern-security-lab-course OpenSpec change once its content is migrated

## 5. lab-infra for the new tools

- [ ] 5.1 `lab-infra/<tool>/` (kind + Helm/compose + up/down) for Boundary+Vault, OpenZiti, Pomerium, Netbird — $0/local/reproducible
- [ ] 5.2 `lab-infra/offense/` for garak/PyRIT + Atomic Red Team/Caldera/Stratus, wired to attack the local stack only; teardown documented

## 6. Verify

- [ ] 6.1 Regenerate markdown views (`scripts/gen-md.mjs`); tracker/quizzes/plan consistent; standards fields render
- [ ] 6.2 Verify in study-hub: ingest clean, links/objectives resolve, SC-500 anchor mapping intact; full course green
- [ ] 6.3 Honesty pass on offensive labs: executed vs. directions clearly labeled, nothing fabricated
