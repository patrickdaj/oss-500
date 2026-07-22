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
- [x] 2.3 Lab: OpenZiti (app-embedded overlay, zero listening ports) — Terraform edge provider (`netfoundry/ziti`); CI-validated `lab-infra/ztna-openziti/`
- [x] 2.4 Lab: Pomerium (identity-aware reverse proxy / BeyondCorp) in front of an internal app — TF-wrapped Helm release; CI-validated `lab-infra/ztna-pomerium/`
- [x] 2.5 Lab: Netbird (WireGuard mesh with identity ACLs) — official Terraform provider (`netbirdio/netbird`); CI-validated `lab-infra/ztna-netbird/`

## 3. Purple-team: offensive validation (new Domain 5 + callouts)

- [x] 3.1 Domain 5 notes: purple-team framing (`purple-team.md`) + three track notes (`ai-redteam.md`, `infra-attack-simulation.md`, `ztna-authz.md`); tracker `d5` added
- [x] 3.2 Lab (AI): `d5-ai-redteam.md` — garak/PyRIT/PortSwigger vs the D3 NeMo-Guardrails gateway; findings → OWASP LLM Top 10 + ATLAS; reuses undefended-Ollama baseline
- [x] 3.3 Lab (infra): `d5-infra-attack-simulation.md` — Atomic/Caldera/Stratus fire ATT&CK at Falco/Tetragon/Suricata/Wazuh; confirm alerts or document gaps
- [x] 3.4 Lab (ZTNA): `d5-ztna-authz.md` — unauthorized-access attempts prove least-privilege on the brokers
- [x] 3.5 Added "validate it" callouts to D1–D4 labs (d3-ai, d3-runtime, d4-network-detection, d4-siem, d2-network-policy, d1-ztna-boundary) linking the attack + technique

## 4. Migrate & retire modern-security-lab

- [x] 4.1 Migrated the OSS substance (Boundary+Vault ✅, OpenZiti, garak/PyRIT/PortSwigger, 800-207/ZTNA framing) into oss-500's D1 (`ztna-access-models.md` + 4 labs) and D5 (`ai-redteam.md` + `d5-ai-redteam.md`); de-duped by re-authoring native — and upgraded to Terraform per the as-code bar (netfoundry/ziti) rather than the modern `ziti`-CLI version
- [~] 4.2 Reduce modern-security-lab to a portfolio artifact — **DESCOPED (user: "focus on oss-500, not ngfw")**. Modern lives in the separate `ngfw` repo; its retirement is deferred to a future ngfw-scoped change. oss-500 already carries the migrated OSS content (4.1), so it stands complete without this step.
- [~] 4.3 Archive the `modern-security-lab-course` OpenSpec change — **DESCOPED** (same separate `ngfw` repo). Deferred with 4.2.

## 5. lab-infra for the new tools

- [x] 5.1 `lab-infra/<tool>/` for Boundary+Vault (✅ 2.2), OpenZiti, Pomerium, Netbird — all Terraform, CI fmt+validate green, $0/local
- [x] 5.2 `lab-infra/offense/` for garak/PyRIT + Atomic/Caldera/Stratus, wired to local-only targets (RFC1918 safety gate in `up.sh`); teardown in `down.sh`

## 6. Verify

- [x] 6.1 Regenerated markdown views (`npm run gen:md`) — 81 objectives, Domain 5 + `standards` column render; tracker consistent; internal links resolve; `terraform fmt -recursive` + per-dir `validate` green for all new labs; shellcheck clean
- [x] 6.2 Verified oss-500 is **ingest-ready** by running study-hub's exact `lint:content` logic against it: **5 domains, 81 objectives, all tracker `notes` paths resolve, quiz `objectiveIds` + answer indices valid**. The actual study-hub run (bump the `content/oss-500` submodule; update its `loader.test.ts` oss-500 expectation from 4→5 domains / 75→81 objectives; `npm test`) is a **study-hub-side follow-up**, out of oss-500's scope per user focus.
- [x] 6.3 Honesty pass: every D5 lab has an explicit "Honesty note" separating executed vs. directions; the only executed claim (garak-vs-Ollama baseline) is labeled as *reused* evidence; nothing fabricated
