# OSS-500 — Persona Walkthrough Audit

**Question asked:** Walk the entire curriculum start-to-finish as one specific learner and find the places that don't make sense — knowledge "jumps" that assume something never taught, and "wild goose chases" where the student burns time figuring out how something works or where to get a tool. Keep it approachable and achievable **without** spoon-feeding.

**The learner persona this audit judges from:**
- Used Linux often but **not** at an admin level, and rusty (some years out). Shell-comfortable; rusty on systemd/journalctl, namespaces/capabilities internals.
- A **crack enterprise firewall engineer**: strong on networking, segmentation, IDS/IPS, TLS/PKI at the protocol level, build/config **standards**, feature **testing**, and **Python** automation. These are treated as existing strengths.
- **Decent Docker**: runs containers, builds compose topologies comfortably.
- Does **not** know Kubernetes beyond the ramp, nor Helm/Terraform/Vault/Istio/SPIFFE-SPIRE/Rego/LLM-security going in.
- Accumulates knowledge at an average-or-better rate as they go (earlier-taught counts as known later).

**Method.** Read the full plan spine (`plan/overview.md` + all 8 phase files) to fix the intended sequence and the knowledge floor, read the six Phase-0 fundamentals notes to fix what the ramp actually establishes, then audited every domain note, every lab (`labs/*.md`), and the backing `lab-infra/` for each of the six domains against that accumulating floor. The most severe findings were independently re-verified against the source files (marked **✔ verified** below).

---

## Headline

**The learning design is strong; the lab *implementation* has drifted from it.** The plan, the fundamentals ramp, the concept-by-concept bridging, the "prove the control, don't just deploy the tool" discipline, the resource budgeting, and the walkthrough signposting are all well done and well sequenced for this persona. Almost every serious problem is the **same failure mode**: a lab's prose was written for an intended environment that the `up.sh`/manifests don't fully build — so the student is told to attack, verify, or log into something that isn't running. That is exactly the "wild goose chase" the design intent forbids, and it clusters in a way that's cheap to fix.

Two distinct problem classes, both mapping directly to the two things the request cares about:

- **Knowledge-sequencing jumps** — a skill/concept is *demanded before it's taught*. Few, but real. (Category A.)
- **Wild-goose-chases** — lab prose contradicts or outruns the actual `lab-infra`, or references a file/tool/target that doesn't exist. Dominant class. (Category B.)
- Plus **tooling "where do I get it" gaps** (Category C) and **structural/coherence** issues (Category D).

**Score of severe items:** ~7 BLOCKER-level (a lab's stated observable cannot be reached as written) + ~10 JUMP-level, spread across all six domains. None are in the *teaching*; nearly all are in the *plumbing*.

**Severity legend:**
- **BLOCKER** — student hits a dead end / missing tool with no pointer / lab instructions contradict the deployed reality; the stated observable can't be produced.
- **JUMP** — a significant unexplained concept/skill leap that will cost real time.
- **FRICTION** — a minor gap a sentence or link fixes.
- **NIT** — polish.

---

## Category A — Knowledge-sequencing jumps (the "doesn't make sense in order" ones)

These are the genuine curriculum-ordering problems, independent of any bug.

1. **[JUMP] Vault is a forward dependency of Phase 1 but isn't taught until Phase 2.** ✔ verified
   Phase 1 Day 6's `d1-ztna-boundary` lab needs a running `vault server -dev` **with the SSH secrets engine enabled and a signing role at `ssh/sign/boundary`** to deliver its headline observable (an *injected*, ephemeral SSH credential). Vault isn't introduced until Phase 2. The lab lists "`vault server -dev` with the SSH secrets engine" as if known and gives **no** `vault secrets enable ssh` / role-creation commands. `labs/d1-ztna-boundary.md:14`, `lab-infra/ztna-boundary/up.sh:4-5`. → A first-time-Vault learner cannot configure an SSH CA engine from that prompt. **Fix:** add the exact enable+role commands to the lab (and a one-line "this front-loads a slice of Domain-2 Vault"), or move the injected-credential proof to a Phase-2 revisit.

2. **[JUMP] Terraform: one 0.5h orientation *read* → author multi-provider HCL for four brokers.** ✔ verified
   Phase 0 establishes Terraform at concept depth only (`domains/0-fundamentals/05-git-iac-foundation.md`): state, providers, `write→plan→apply` — but the student never writes a `.tf` or runs `terraform`. Phase 1 Day 6 then asks them to build four ZTNA stacks "yourself" across five providers (`hashicorp/boundary`, `hashicorp/vault`, `netfoundry/ziti`, `netbirdio/netbird`, `hashicorp/helm`) with variables, `sensitive` outputs, and provider blocks. The config-standards background softens this and a CI-validated reference exists, but first HCL authoring will cost real time. **Fix:** add a tiny "write your first `.tf`, run init/plan/apply" hands-on to Phase 0, and/or explicitly frame the ZTNA labs as *read-then-adapt the reference*, not blank-page authoring.

3. **[JUMP] SPIRE: walkthrough-only in Phase 1 → expected to operate it in Phase 6.** ✔ verified (see also D-2, B-6)
   Phase 1 covers SPIFFE/SPIRE as a *walkthrough* (no server ever runs). Phase 6 then hinges on a running SPIRE server (agent SVIDs, peer mTLS). The Phase 6 *plan* is honest that this is "directions you stand up yourself," but that is a large jump for someone who has never operated SPIRE — and the labs/notes make it worse by pretending it's already running (see B-6). **Fix:** either ship a real SPIRE install for Phase 6, or explicitly re-label the SVID-issuance proofs as walkthrough/directions (as federation already is) so the running proof is clearly optional.

4. **[FRICTION] Rego is written before it's taught as a language.** Governance (Phase 1) asks the student to write a Gatekeeper `ConstraintTemplate`'s Rego, and Phase 6 asks for a default-deny policy + argument guardrail. Rego is never taught as a language. *Both spots are well-scaffolded* with near-complete cribs in the notes and reference `.rego` files, so this is minor — but worth a one-line pointer to the crib + the Rego playground at first use. `labs/d1-governance-policy.md` Part B; `domains/6-agentic-zero-trust/d6-tools-mcp.md:21-45`.

---

## Category B — Wild-goose-chases (lab prose vs. actual `lab-infra`)

The dominant class. Each is a place the student is told to interact with something the environment doesn't actually build.

### Phase 2 — Secrets, data, networking

- **[BLOCKER] Vault dynamic-secrets lab has no Postgres backend and no psql client.** ✔ verified
  The `vault-dynamic` observable (a DB credential that Postgres accepts, then stops accepting after lease revocation) needs a Postgres the environment never creates. The prereq claims "the component's `up.sh` deploys one, or apply `lab-infra/secrets/postgres.yaml`" — but `secrets/up.sh` installs only Vault + the CSI driver, and **`postgres.yaml` exists nowhere in the repo** (confirmed by search); `configure.sh` punts with "The lab deploys the Postgres pod." `vault write database/config/appdb …` fails its connection check and `psql -h postgres.oss500-secrets` has no server and no psql-capable pod. `labs/d2-vault-dynamic-secrets.md` Part C. **Fix:** ship `lab-infra/secrets/postgres.yaml` (Postgres Deployment/Service + a psql client pod) and apply it in `up.sh`.

- **[BLOCKER] Vault is deployed dev-mode, but Part A teaches Raft + Shamir + reads a `.vault-init.json` that's never generated.** ✔ verified
  `lab-infra/secrets/values.yaml` sets `server.dev.enabled: true` with `devRootToken: "root"` (in-memory, auto-unsealed, Raft blocks commented out). The lab tells the learner to `vault login` with the root token "from the gitignored `secrets/.vault-init.json`" (only a `vault-init.json.example` exists — nothing generates the real file), expects `vault status` to show `Storage Type raft`, runs `vault operator raft list-peers` (errors on `inmem`), and walks a Shamir seal/unseal cycle that's impossible with zero shares. `labs/d2-vault-dynamic-secrets.md` lines ~19,25 + Part A. → Every Part-A instruction contradicts the deployed reality — a maximal time-sink on the persona's very first Vault contact. **Fix:** rewrite Part A to match dev mode (token is literally `root`; frame Raft/Shamir as the commented production path), or switch the component to a real single-node Raft init that actually writes `.vault-init.json`.

- **[JUMP] Mesh "allowed identity → 200" happy path never matches a real workload.** The `net-mesh` observable is an authorized call returning 200, but no `frontend-sa` ServiceAccount/workload is created, and the shipped `AuthorizationPolicy` allows principal `…/sa/client` while the demo `client` pod runs under the **default** SA (SPIFFE id `…/sa/default`) — so the allow never matches and an authorized call still 403s. `labs/d2-network-policy.md` Part B steps 7-10; `lab-infra/network/mesh/authorizationpolicy.yaml`. Istio SPIFFE-identity wiring is new for this persona; "why is my *allowed* call denied" is the exact rabbit hole to avoid. **Fix:** add a ServiceAccount + a pod running as it whose principal matches the policy.

- **[FRICTION] WAF snippet annotations are silently disabled.** Parts B-D are built entirely on per-Ingress `modsecurity-snippet` annotations, but `lab-infra/network/ingress-values.yaml` never sets `allow-snippet-annotations: "true"` (off by default in modern ingress-nginx), so DetectionOnly→On and `SecRuleRemoveById` tuning are no-ops. The WAF note flags the gotcha, so a WAF-strong reader recovers — friction, not blocker. **Fix:** set `allow-snippet-annotations: "true"`.

### Phase 3 — Compute & AI security

- **[BLOCKER] The AI gateway and NeMo Guardrails are never deployed — the four AI-security observables can't fire.** ✔ verified
  `lab-infra/ai/up.sh` deploys Ollama, Open WebUI, and the OTel collector as real workloads, but creates `nemo-guardrails` and `ai-gateway-policy` only as **inert ConfigMaps** — there is no gateway/guardrails Deployment or Service. Open WebUI points `OLLAMA_BASE_URL` straight at Ollama, so nothing sits in the request path. The lab then tells the student to `curl http://ai-gateway.oss500-apps:8080/v1/chat` and expect a 401/429, a blocked jailbreak, a redacted output secret, and `guardrail.blocked` spans — none reachable. `labs/d3-ai-security.md` Parts A-E; `lab-infra/ai/README.md:11-12` even lists these as "Deployment," contradicting the manifests. **Fix:** ship a real `ai-gateway` Deployment (guardrails + OPA in-path) + a NeMo Guardrails server, and route Open WebUI through it — or rewrite the lab to attack Ollama-via-Open-WebUI and stop referencing a gateway that isn't there.

- **[JUMP] Ollama NetworkPolicy contradicts the "gateway is the only path" claim and gates on labels the lab calls ServiceAccounts.** The policy allows ingress from `app: ai-gateway`/`app: nemo-guardrails` (pods that never exist) **and** `app: open-webui`, so the live path bypasses any rail; step 2 also tells the learner to inspect "which ServiceAccount(s) it allows" but the manifest selects by pod **label**. `lab-infra/ai/ollama/deployment.yaml:79-84`. **Fix:** once a gateway exists, make it the sole allowed client and correct the wording to "podSelector labels."

- **[FRICTION] Harbor self-signed CA / `/etc/hosts` setup is promised but absent.** `supplychain/README.md:41` says CA-trust / `--allow-insecure-registry` is "documented in the lab steps," but `labs/d3-supply-chain.md` Part C jumps straight to `docker login harbor.oss500.local` / `docker push` / `cosign sign` with no `/etc/hosts` line and no CA-trust step — which fail with cryptic x509 errors against a self-signed local registry. **Fix:** add the `/etc/hosts` entry and CA-trust (or `--allow-insecure-registry`) note to Part C.

### Phase 4 — Posture & monitoring

- **[BLOCKER] SIEM agent joins a docker network the manager isn't on — onboarding fails.** ✔ (verified by auditor; mechanism confirmed)
  Everything runs as `docker compose -p oss500-siem`, so the stack network is `oss500-siem_default`, but `lab-infra/siem/agent-compose.yml:22-25` attaches the agent to `oss500_default` (declared `external: true`, so Compose won't create it). The onboarding `up` errors with "network oss500_default … could not be found" (or the agent can't resolve `wazuh.manager`), so it never enrolls — killing `siem-collect`, `siem-detect`, `siem-hunt`, and `siem-response` (4 of 5 stages). **Fix:** set `agent-compose.yml` `networks.default.name: oss500-siem_default`.

- **[JUMP] The "provisioned OSS-500 posture dashboard" the lab opens is never shipped.** `labs/d4-observability.md` Part D says the dashboard is "already loaded via the sidecar; find it under Dashboards" (5xx rate / pods-as-root / failed-auth / trace latency), but no `grafana_dashboard` ConfigMap/JSON exists in `lab-infra/observability/` and `up.sh` applies only datasources/otel/alerts. The `obs-dashboards` deliverable and the metrics→logs→traces drill-down are undoable as written; authoring Grafana JSON was never taught. **Fix:** ship a dashboard ConfigMap labelled `grafana_dashboard` and apply it in `up.sh` (or reword Part D to "build the panels in Explore" — the trace→log link is already provisioned).

- **[FRICTION] Sigma `sigma convert` step gives three conflicting pipelines and a likely-unconvertible rule.** The rule header says `-p sysmon`, the reference says `-p ecs_windows`, the prose says "linux pipeline"; for a `product: linux, service: sshd` rule none is right, `pysigma-backend-opensearch` ships no linux/sshd ECS pipeline, and the `| count() by src_ip > 5` aggregation is old-style syntax current pySigma won't convert. A native-Wazuh rule (`100100`) is the working fallback, so not a dead end. `lab-infra/siem/sigma/ssh-bruteforce.yml`; `labs/d4-siem-wazuh.md` step 9. **Fix:** make the `-p` flag consistent and valid (or drop it) and simplify the rule to a convertible form / state the Wazuh-rule fallback up front.

- **[FRICTION] Network-detection lab replays a "shipped" PCAP that doesn't exist.** Prereqs say "the stack ships one" and step 4 runs `suricata -r /pcaps/testmynids.pcap`, but `lab-infra/network-detection/pcaps/` has only a README and `up.sh` just `mkdir -p pcaps`; the READMEs say capture your own with `tcpdump`. → "file not found," then a hunt for the capture-it-yourself path. **Fix:** commit a small benign `testmynids.pcap` or reword to the capture-your-own flow already documented.

### Phase 5 — Offensive validation

- **[BLOCKER] The AI red-team target (the guardrailed gateway) never stands up** — direct cascade of the Phase 3 blocker. `labs/d5-ai-redteam.md` Part B fires garak at the "NeMo-fronted gateway," but that gateway is only ConfigMaps (see Phase 3), so Part B, the defended-vs-baseline delta table, and Verification are all unreachable. **Fix:** same as Phase 3 — ship a real gateway, or retarget the lab to the surface that actually runs.

- **[JUMP] garak REST generator configs are referenced but don't exist, and Ollama isn't reachable.** The lab uses `-G localhost-ollama.json` and `-G <gateway-config>.json` as if shipped; neither is in the repo and `lab-infra/offense/up.sh` doesn't generate them. Ollama is ClusterIP-only (`:11434`), so even the baseline needs a `kubectl port-forward` that's never mentioned. Hand-authoring a garak REST generator JSON is the load-bearing hard part for a garak newcomer. **Fix:** commit a working `localhost-ollama.json` and add the port-forward step.

- **[JUMP] PyRIT "script a multi-turn orchestrator" with zero starter code.** `labs/d5-ai-redteam.md` Part C asks the learner to design an escalation across turns; `up.sh` installs PyRIT but provides no example. Python-strong, but PyRIT's targets/orchestrators/scorers are new. **Fix:** add a ~20-line `PromptSendingOrchestrator`/`RedTeamingOrchestrator` skeleton to `lab-infra/offense/`.

- **[JUMP] ZTNA lab omits the broker re-stand-up the plan requires.** The brokers were torn down at the end of Phase 1 (three phases earlier). `plan/phase5-offensive-validation.md:30` correctly carries an explicit "re-stand-up the `lab-infra/ztna-*` broker(s)" prerequisite — but `labs/d5-ztna-authz.md:13-14` only says "at least one ZTNA broker up from Domain 1" and links the D1 labs, implying they're still running. **Fix:** mirror the plan's prerequisite into the lab (`cd lab-infra/ztna-<broker> && ./up.sh`).

- **[FRICTION/NIT] Atomic T1611 has no runnable Linux action in an `alpine` pod; Caldera quick-start skips `pip install -r requirements.txt`.** `labs/d5-infra-attack-simulation.md:63-72`. **Fix:** give the concrete Linux T1611 action (privileged pod + `nsenter`) and add Caldera's requirements-install step.

### Phase 6 — Agentic zero trust

- **[BLOCKER] Labs/notes claim SPIRE is "already running from Domain 1" — it was never deployed.** ✔ (verified: zero `spire` refs in `lab-infra/` outside `agentic/`)
  `lab-infra/identity` deploys only Keycloak + PostgreSQL, yet the first step of the first Phase-6 lab is `kubectl -n oss500-identity exec deploy/spire-server -- …`, which dead-ends with `deployments.apps "spire-server" not found`. The infra docs correctly say SPIRE is *not* deployed — a direct contradiction that reads to the learner as "my Domain-1 setup is broken." `labs/d6-identity.md:15,27`; `domains/6-agentic-zero-trust/d6-identity.md:7,15-19`; `labs/d6-multi-agent.md:14-15`. **Fix:** remove every "already running / reused from Domain 1" SPIRE claim; match the honest infra docs.

- **[BLOCKER] `spire/registration.md` is a hand-wave, not a followable stand-up path.** `lab-infra/agentic/spire/registration.md:3-17` says only "stand up a SPIRE server/agent yourself (e.g. the Helm chart)"; the sole concrete command (`spire-server entry create`) presupposes a configured server+agent, the `oss500.local` trust domain, k8s PSAT attestation, a `spire-agent` daemonset, and the Workload API socket mounted into pods — none provided. Yet `agent-workload`/`agent-mtls` are presented as *runnable* proofs. For someone who's never operated SPIRE, this is a multi-hour yak-shave. **Fix:** ship a real SPIRE install (Helm values + spire-agent daemonset + socket wiring) under `lab-infra/agentic/spire/`, or re-label those proofs as walkthrough.

- **[JUMP] Keycloak token-exchange feature isn't enabled, with no bridge to enable it.** `lab-infra/identity/values.yaml` sets no `KC_FEATURES`, so token exchange is **off**; `lab-infra/agentic/keycloak/token-exchange.md` says "add it and restart" but never shows how to inject `--features` into the bitnami chart (`extraEnvVars: KC_FEATURES=…` + `helm upgrade` + restart). Until done, every Part-B token-exchange call 401s. It also conflates GA "standard token exchange" (Keycloak 26+) with the legacy preview flag, so a Keycloak-new learner can't tell which their chart needs. **Fix:** add the exact bitnami `extraEnvVars`/`helm upgrade` snippet and name the flag for the chart's version.

- **[FRICTION] The agent has source but no way to run it.** `lab-infra/agentic/up.sh` only stuffs `agent.py`/`server.py` into ConfigMaps; there's no Deployment/Job, no venv steps, and required env vars (`KEYCLOAK_URL`, `MCP_URL`, `OLLAMA_URL`, `AGENT_CLIENT_ID/SECRET`) are never wired, though labs reference `kubectl logs deploy/agent-a`. Python-strong learners bridge it, but it's an unsignposted assembly step. **Fix:** add a "run it (venv env vars, or apply this Job)" block or a minimal Deployment.

---

## Category C — Tooling / "where do I get it" gaps (systemic)

- **[JUMP] The prerequisite list covers 5 tools; the labs invoke ~25.** ✔ verified
  Both `README.md` and `lab-infra/README.md` list prerequisites as **Docker, kind, kubectl, Helm** (+ git). But across `labs/*.md` the commands invoke roughly two dozen more CLIs: `terraform, vault, boundary, ziti, ziti-edge-tunnel, netbird, tsh, tctl, cmctl, istioctl, cilium, hubble, trivy, grype, syft, cosign, gitleaks, opa, kubescape, kube-bench, sigma, garak, pyrit, caldera, stratus, psql`. There is **no central "install-as-you-go" tools page** and **no per-lab Prerequisites/Tools convention** — install pointers are ad hoc (the Teleport, supply-chain, and governance labs link/echo installs well; the ZTNA, AI-`opa`, cert-`cmctl`, and data-protection `trivy`/`gitleaks` labs don't). The `tf.sh` wrapper runs `terraform init/apply` and simply dies if it's absent, yet Terraform is never listed as a prereq and its install link is buried in a fundamentals "primary sources" list. → Repeated `command not found` papercuts, worst when the install method is non-obvious (`boundary`, `ziti`'s two binaries, `garak`/`pyrit` via pipx). **Fix:** add a single `TOOLS.md` matrix (tool → phase first used → one-line install) and give every lab a short "Tools for this lab" prereq block; explicitly promote Terraform to a first-class prerequisite.

Individual instances already captured above: `opa` (Phase 3), `trivy`/`gitleaks` (Phase 2 data-protection), `cmctl` (Phase 2 cert), ZTNA CLIs + `terraform` (Phase 1).

---

## Category D — Structural / coherence

1. **[JUMP] `d2-fabric` (Cilium eBPF network fabric) is a tracked objective and full lab, but the plan never sequences it.** ✔ verified
   `assessment/data/tracker.yaml` lists `d2-fabric` with five subsections (`fab-cni`, `fab-egress`, `fab-fqdn`, `fab-flowlogs`, `fab-peering`), a note (`domains/2-secrets-data-networking/network-fabric.md`), a large lab (`labs/d2-network-fabric.md`), and a `lab-infra/network/cilium/` component — and it's in the labs catalog. But **`plan/phase2` references none of them**; a student following the plan day-by-day never encounters it. Since the readiness gate requires *every* tracker objective green, the plan as written cannot produce a green tracker. (The lab itself is self-contained and followable, and correctly handles the kindnet→Cilium CNI swap via `kind delete`/recreate — so this is a *sequencing* gap, not a broken lab.) **Fix:** either add a Phase-2 day for the fabric (it introduces heavy new concepts — eBPF CNI, Egress Gateway, Hubble, Cluster Mesh — so budget a full day), or mark `d2-fabric` explicitly optional/beyond-plan and exempt it from the readiness gate.

2. **[JUMP] Plan-vs-content contradiction on SPIRE (Phase 6).** The Phase 6 *plan* is honest that SPIRE is directions-only; the Phase 6 *labs and notes* say the opposite ("reused from Domain 1," exec into `spire-server`). The files that must agree don't. (Same root as B-6.) **Fix:** make labs/notes match the plan's honest framing.

3. **[NIT] Tracker objective IDs aren't cited by the plan for ~12 objectives whose *content* is sequenced.** IDs like `rbac-roles`, `rt-falco`, `vuln-cis`, `gov-kyverno`, `sc-admission`, `ai-prompt` don't appear verbatim in `plan/`, though their notes/labs are sequenced (unlike `d2-fabric`, whose note/lab/ID are all absent). The plan's "each miss maps to an objectiveId" model has looser id-level traceability here. Harmless to learning; a polish item if you want quiz-miss → note links to be exact. **Fix (optional):** cite objective IDs in the plan day items, or accept note/lab references as the mapping.

4. **[NIT] Dead references.** `lab-infra/encryption/up.sh` points at a nonexistent `verify-etcd.sh`; `labs/d2-data-protection.md` cites `encryption/keygen.sh`/`encryption-config.secret.example` that don't exist; `lab-infra/ai/README.md` lists gateway/guardrails "Deployment" rows that are ConfigMap-only; `configure.sh` uses `postgres.oss500-apps` while the lab uses `postgres.oss500-secrets`. **Fix:** delete/repair each.

---

## What is genuinely well done (so it isn't lost in the fix pass)

- **The plan spine and ramp.** `overview.md` + Phase 0 build platform fluency in the right order for this persona: Linux→containers→k8s primitives→kind/Helm→git/Terraform orientation→RBAC preview, each with a self-check gate. The ramp explicitly leans on the persona's networking strength and shores up the k8s gap.
- **Concept bridging in the notes.** Keycloak OIDC/OAuth client types, the LLM threat model (built from zero — appropriate, since AI security is new-to-SC-500), Falco/Tetragon rule authoring, cosign/sigstore keyless, RFC 8693 delegation-vs-impersonation, and the ATT&CK/ATLAS/OWASP-LLM taxonomies are all introduced with worked examples and primary-source links before they're used — not dropped as jargon.
- **"Prove the control" discipline.** Every lab ends in an observable (a denied request, a fired alert, a blocked connection), and the overview enforces it as rule 4. This is the right pedagogy and is consistent across all six domains.
- **Resource honesty.** The 16 GB reference host, "run the SIEM and observability stacks alone," the Apple-Silicon/Docker-Desktop eBPF caveat, and per-phase footprint tables are explicit and repeated — a laptop learner isn't blindsided.
- **Walkthrough signposting.** Where a control can't run on the reference host (HSM/PKCS#11, perimeter firewall, federation, MCP-over-HTTP), it's clearly marked walkthrough — *except* the SPIRE case, which is the one place the signposting breaks (B-6).
- **Correctly-cleared traps.** The kindnet-vs-Calico NetworkPolicy trap, the etcd-on-kind static-pod edit, the SIEM detection-ID chain (`5710`→`100100`→active-response), and the offense "local targets only" RFC1918 gate are all handled properly.

---

## Suggested fix order (highest learner-time-saved first)

1. **Make each lab's `up.sh`/manifests actually build what the lab tells the student to attack/verify.** One pass over the drift closes most blockers: AI gateway+guardrails (P3/P5), Vault dev-mode vs Raft + Postgres backend (P2), SIEM agent network name (P4), Grafana dashboard (P4), SPIRE (P6), garak configs (P5). This is the single highest-value change.
2. **Fix the SPIRE and Vault *forward/contradiction* problems** (A-1, A-3, B-6, D-2) — they cause the most confusing "is my earlier setup broken?" spirals.
3. **Add `TOOLS.md` + per-lab tool prereqs, and promote Terraform to a listed prerequisite** (C).
4. **Sequence or explicitly de-scope `d2-fabric`** so the plan can produce a green tracker (D-1).
5. **Add the two small authoring on-ramps** — a first-`.tf` exercise (A-2) and a first-Rego crib pointer (A-4).
6. Sweep the FRICTION/NIT items (WAF snippet toggle, Harbor CA note, Sigma pipeline, missing PCAP, dead references).
