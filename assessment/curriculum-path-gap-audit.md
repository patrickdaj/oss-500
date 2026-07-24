# OSS-500 — Curriculum Path Gap Audit (senior-network-engineer lens)

**Question asked.** Walk the *entire* path a senior **network** security engineer takes through OSS-500 — someone strong on firewalls/segmentation, IDS/IPS, TLS/PKI at the protocol level, build/config standards, and Python automation, but **new to cloud, Kubernetes, Terraform, and AI/agentic security**. Find (1) sequencing jumps that don't make sense, (2) whether he has the knowledge to go through in the order presented, and (3) whether each note **teaches standalone** or silently offloads the real learning to references — and if it offloads, **name which references are 100% necessary** so a student doesn't drown in a link list not knowing which one is load-bearing. Goal: get this engineer to intermediate-to-expert across cloud, containers/Kubernetes, Terraform, AI, and agentic security. Output: a report that can be turned into OpenSpec changes.

**Method.** Read the full plan spine (`plan/overview.md` + all eight phase files), the six Phase-0 fundamentals notes, and — via one reader per domain — every domain note and its labs in Domains 1–6, judged against an accumulating knowledge floor (earlier-taught counts as known later). This audit is a **companion** to `persona-walkthrough-audit.md`: that one found lab-*plumbing* drift (mostly since fixed/archived); this one is about *teaching sequence and reference-dependency*, which the plumbing pass did not cover.

---

## Headline

**The path is sound and the learning design is genuinely strong — but the curriculum consistently introduces a new *language, protocol, or framework* in the same breath it first *uses* it, and it never tells the student which of the 4–6 links under each note he actually has to read.** Both problems hit this persona precisely where he's weakest (cloud/K8s/AI authoring) and spare him where he's strong (networking, PKI, IDS, Python). Neither is a design flaw; both are cheap, additive fixes.

A deeper lab-by-lab pass (folded into Part 3) also surfaced a **second, distinct class**: lab-correctness blockers where the environment can't produce the stated observable — led by one *systemic* issue (bare pods in a PSA-`restricted` namespace, which breaks four admission/runtime labs at once). These overlap the plumbing domain of the earlier `persona-walkthrough-audit.md`, but several are new or re-opened, and they matter to question 2 (can he proceed in order?) because a stranded observable stops a careful engineer cold.

Direct answers to the three questions:

1. **Sequencing jumps** — real but bounded. They cluster into one repeating pattern: *a foundational skill is demanded before any note teaches it.* Nine instances, listed below. The domain *concept* ordering (identity → secrets/net → compute/AI → posture → offense → agentic) is correct and the milestones gate properly.
2. **Does he have the knowledge to go in order?** — **Yes for the security spine, no for the authoring substrate.** His networking/PKI/IDS/Python strengths carry large stretches unaided (Domain 2 certs & fabric, Domain 4 network-detection & SIEM, Domain 5 infra & ZTNA attacks). He is blocked only where the curriculum assumes an *authoring* skill it never taught: writing a Kubernetes manifest, writing Terraform HCL, writing Rego, and reasoning about OAuth/JWT, LLM, MCP, and eBPF internals.
3. **Standalone vs reference-dependent** — **most notes are self-contained**; the reference *citation quality* is already high (deep links, time estimates, `(reference)` marking, governed by the `resource-citation` spec). The gap is that **no note ranks a link as "you must read this before the lab" vs "enrichment."** The genuinely load-bearing references are few and nameable (below) — the fix is a one-word tag, not new prose.

**Severity legend:** **BLOCKER** = the student cannot complete/verify or answer the quiz from course materials · **JUMP** = a real, unbridged skill/concept leap that costs hours · **FRICTION** = a sentence or tag fixes it · **NIT** = polish.

---

## Part 1 — The dominant pattern: "used before it's taught" (prerequisite primers)

Every item here is the same shape: a language/protocol/framework is *authored or reasoned about* in a lab before any note teaches it. The persona's transferable skills soften some and not others. Each is a candidate OpenSpec change adding a short primer at the point of first need.

| # | Missing primer | First demanded at | Persona-softened? | Severity |
|---|---|---|---|---|
| P1 | **Rego as a language** | D1 `governance` lab Part B (author a violation rule); again D3 `ai-governance` (`opa eval`), D6 ×3 (`tool-authz`, `action-class`, guardrail) | **No** — Python fluency does *not* transfer to Rego's declarative/partial-set model | **JUMP** (highest frequency in the course) |
| P2 | **OAuth 2.0 / OIDC / JWT anatomy** | D1 `identity-provider` (five grant types named, no flow walked); labs decode JWTs at `jwt.io` | Partly — PKI helps with signing/JWKS, not with grant flows or `act`/`aud` semantics | **JUMP** |
| P3 | **LLM mechanics** (token, context window, system/user prompt, embedding, vector store, the RAG loop) | D3 `ai-security` intro (assumes all of it) | No — this is the AI-newcomer half of the persona; there is a Linux/containers on-ramp but no AI on-ramp | **JUMP** |
| P4 | **Terraform HCL authoring** (`resource`/`variable`/`output`/`sensitive`/`tfvars`, attribute refs) | D1 Day 6 ZTNA labs (author multi-provider configs) | Partly — config-standards mindset helps; blank-page HCL does not exist in Phase 0 | **JUMP** |
| P5 | **Kubernetes manifest authoring** (`securityContext`, probes, limits in YAML) | Phase 0 self-check #1 itself; then D1 Day 3/5 | No — Phase 0 is entirely imperative (`kubectl create`); he exits never having written a pod spec | **JUMP** |
| P6 | **MCP protocol** (client/server, stdio vs HTTP transport) | D6 `d6-tools-mcp` (whole `mcp-authn` objective turns on transport type) | No | **JUMP** |
| P7 | **LangGraph execution model** (node/state/checkpointer, `interrupt()`) | D6 `d6-action-gating` (implement pause/resume) | Partly — can *read* `agent.py`, cannot implement the framework from the note; **and the cited link points at the repo root, not the human-in-the-loop/`interrupt()` doc** | **JUMP** + wrong ref |
| P8 | **eBPF as a concept** (hook points, verifier, kprobe vs LSM) | D3 `runtime-security` (Falco/Tetragon) and D2 Cilium | Partly | **FRICTION**→JUMP |
| P9 | **SPIRE operation** (running a server, `entry create`, Workload-API socket) | D6 `d6-identity` (first live operation) | Partly — PKI analogy (SVID≈short-lived cert) is the note's mitigant | **JUMP** (honestly signposted, but the first hands-on SPIRE anywhere) |

**Why this matters for the stated goal.** The course wants an *expert* outcome. On the topics the persona already owns, the notes correctly teach *why* and let his experience carry the *how*. On these nine, the notes teach *why* well but the *how* is pushed to an external doc every time — which is exactly the "intermediate, not expert; and dependent on references" outcome the audit is trying to prevent.

**Highest-leverage subset:** P1 (Rego), P2 (OAuth/JWT), P3 (LLM mechanics) — each is reused across ≥2 domains, so one primer pays off repeatedly.

---

## Part 2 — The reference-ranking problem (the student's literal complaint)

Across all six domains the finding is identical: notes list 4–6 resources per objective with time estimates and sporadic `(reference)` tags, but **give no signal for which link is required to do the lab, required to pass the quiz, or optional depth.** The `resource-citation` spec already governs link *specificity*; it does **not** cover link *necessity ranking*. That's the missing piece.

The good news: the load-bearing references are few and nameable. If a student only knew which these are, the "drowning in links" problem is solved:

| Domain | Reference that is *actually* mandatory | Because the note under-teaches… |
|---|---|---|
| D1 | OPA — Rego policy language | Rego syntax (P1) — needed to author the `governance` lab Part B rule |
| D1 | Terraform provider registry docs (boundary/ziti/netbird) + NetBird self-host quickstart | each ZTNA tool's object model (see Part 4, ztna "lobby" note) |
| D2 | Vault policies doc | KV-v2 `secret/data/` path duality (Part 3) |
| D2 | ModSecurity Reference Manual | `SecRule` anatomy — declared in `waf-rules` exam scope, never shown |
| D2 | Kubernetes "Encrypting data at rest" task page | static-pod surgery + recovery (Part 3) |
| D3 | OWASP LLM Top 10 | only 5 of 10 risks are taught in-note, but "know the number" is in scope |
| D3 | OTel GenAI semantic conventions | the lab step openly says "look them up" |
| D4 | Prometheus querying-basics (PromQL) | the data model — the note teaches PromQL by example only (Part 3) |
| D4 | pySigma/sigma-cli backend docs | Sigma pipelines — and the note's example is *wrong* (Part 3) |
| D6 | MCP authorization spec; Keycloak token-exchange doc; RFC 8693 §1.1 | MCP (P6), Keycloak admin click-path, delegation semantics |

**Proposed change:** extend `resource-citation` with a necessity tag on every learning link — e.g. `[required-for-lab]`, `[required-for-quiz]`, `[depth]` — and add it to the lint. Near-zero cost, directly answers the complaint, and most links resolve to `[depth]` (confirming how self-contained the notes already are).

---

## Part 3 — Note-vs-lab / note-vs-infra contradictions that strand a careful reader

A senior engineer reads the prerequisite note *before* the lab and stops the moment the enforcement point looks unreal. These are places the note contradicts the lab it prepares — teaching-correctness bugs distinct from the plumbing drift the prior audit fixed. A deeper lab-by-lab pass (below) surfaced more of these than the note-level read alone; the highest-value one is systemic and heads the list.

**★ [SYSTEMIC BLOCKER] The PSA-`restricted` namespace collision breaks the headline observable of four admission/runtime labs.** `lab-infra/shared/namespaces.yaml` labels `oss500-apps` with `pod-security.kubernetes.io/enforce: restricted`. Built-in PodSecurity admission runs *before* validating/mutating webhooks and short-circuits, so any bare `kubectl run`/`kubectl create` pod that isn't restricted-compliant is rejected by **PSS, not by the control the lab is demonstrating**:
- **D1 `d1-governance-policy` Part A** — the privileged demo pod is denied by PSS, never by Kyverno; the pivotal "flip to `Audit` → pod admitted → violation in a PolicyReport" step is impossible.
- **D3 `d3-pod-security` Part C** — the `evil` pod is PSS-rejected before the Kyverno `ValidatingAdmissionWebhook`, so the learner never sees "rejected by Kyverno with your custom message."
- **D3 `d3-runtime-detection`** — the victim pod is rejected at admission; and because `restricted` forces non-root, `cat /etc/shadow` fails with EACCES before a descriptor exists, so Falco's `Read sensitive file untrusted` rule (which needs a *successful* open) never fires and the lab's own "the read succeeds and is reported after the fact" framing is false.
- **D3 `d3-supply-chain` Part D** — the "signed image **admitted**" case is unreachable (Kyverno passes it, PSS then rejects it).

In every case the negative test still works (the reject happens, just from the wrong controller) and the positive/observable test fails. For a K8s-newcomer this is the worst failure mode: the lab appears to "work" but shows the wrong error, and Day 6 weak-spot review chases a control that is behaving correctly. **Fix (one change, four labs):** run these demos in a dedicated non-`restricted` demo namespace (e.g. `gov-demo`/`runtime-demo` with an `owner` label), ship restricted-compliant victim/target manifests where a root read is genuinely needed, and — because this *is* the lesson — add one sentence per lab on admission-controller ordering (built-in PSA before webhooks). This is the single highest learner-time-saved fix in the audit.

The remaining contradictions are per-lab:

1. **[BLOCKER] CNI enforcement story is self-contradictory.** `domains/2-secrets-data-networking/network-security.md` (§ segment east-west, ~lines 41, 63) says "this course **installs Calico** in `lab-infra/network/`… kindnet's support is limited." The lab `labs/d2-network-policy.md` and `lab-infra/network/up.sh` say the opposite: no CNI is installed, kindnet enforces Part A, Calico is optional/manual. *Flagged independently by two readers.* For a segmentation specialist, ambiguity about whether the policy is even enforced is disqualifying. **Fix:** make the note match the lab (kindnet enforces; Calico optional).

2. **[BLOCKER] Sigma conversion step is uncompletable from course materials.** `labs/d4-siem-wazuh.md` Part C step 9 demands the correct `-p` pipeline for a `product: linux, service: sshd` rule, never names one, and the **reference solution shows `-p ecs_windows` (a Windows pipeline) then parenthetically says "use the linux pipeline"**; `siem-incident-response.md` `siem-detect` models the same wrong command. **Fix:** teach `sigma list pipelines`, name the correct opensearch/linux pipeline, correct both examples.

3. **[BLOCKER] PromQL: the note's flagship example exceeds what the note teaches.** `domains/4-posture-monitoring/observability.md` `obs-alerting` uses `* on(namespace,pod) group_left` (vector matching, taught nowhere), and line ~27 contains a garbled `... unless kube_pod_container_status_running` expression. A zero-Prometheus learner cannot parse the note's headline security alert *from the note*. **Fix:** add an instant-vs-range-vector + vector-matching primer inline; repair the broken example. (Also verify `kube_pod_spec_containers_security_context_privileged` is actually exposed by the lab's kube-state-metrics — it likely isn't, which would make the note's privileged-pod query return empty.)

4. **[JUMP] Loki→alert bait-and-switch.** The observability lab builds the detection as a LogQL rate (Part B), then Part E's reference alert silently switches to a Prometheus counter (`authlog_failed_logins_total`). The Loki-ruler / log-derived-metric mechanism is never taught, so a learner following Part B's logic writes a non-evaluating `PrometheusRule`. **Fix:** one paragraph in `obs-alerting`.

5. **[JUMP] Vault KV-v2 path & template dualities — guaranteed first-Vault failure.** `secrets-management.md` grants `secret/data/app/*` in policy but uses `secret/app/...` in every CLI example without explaining KV-v2's `data/` infix; the injector section uses `{{ .Data.username }}` while `labs/d2-vault-k8s-injection.md` uses `{{ .Data.data.username }}`. Both are the canonical newcomer tripwires and both land on "your turn" scaffolds. **Fix:** one paragraph on path duality (`vault-access`) + one on KV-v2-vs-dynamic response shape and a two-line Go-template primer (`vault-k8s`).

6. **[FRICTION] WAF: duplicate `id:900110` + untaught custom rules.** `labs/d2-ingress-waf.md` Part C reference uses two `SecAction` directives with the same `id:900110` (ModSecurity rejects duplicate IDs → config-load error nothing prepares him for); and `waf-rules` puts custom `SecRule` authoring in exam scope while neither note nor lab shows `SecRule` anatomy. **Fix:** collapse to the note's single combined `SecAction`; add a minimal `SecRule ARGS "@rx …" "id:…,phase:2,deny"` example or mark the gotcha beyond-lab.

7. **[FRICTION] Static-pod surgery with no safety net.** `labs/d2-data-protection.md` Part A has the learner hand-edit `/etc/kubernetes/manifests/kube-apiserver.yaml` on the node; static pods, kubelet's manifest-watch, and recovery-when-apiserver-won't-return (no `kubectl`; `docker exec` + revert) are taught nowhere. **Fix:** 4–6 sentences in `data-protection.md` `data-encrypt`.

8. **[JUMP] Mesh authorization principal mismatch.** `labs/d2-network-policy.md` Part B reference uses principal `…/sa/frontend-sa` and policies `deny-all`/`allow-frontend`; the shipped `lab-infra/network/mesh/authorizationpolicy.yaml` uses `…/sa/client` and different policy names/deny mechanism. Worse, the `client` pod in `demo-app.yaml` sets no `serviceAccountName` (runs as `default`), so even the *shipped* policy denies it — the "authorized call → 200" observable is unreachable on both paths. **Fix:** add the `client` (or `frontend-sa`) ServiceAccount to `demo-app.yaml`, set `serviceAccountName` on the client pod, and make lab + reference use that one principal.

9. **[BLOCKER] Istio mesh: the shipped default-deny egress starves sidecars of istiod.** With namespace-wide default-deny **egress** in force (kindnet enforcing it, per Part A), injected Envoy sidecars can't reach istiod on `15012` for xDS/cert issuance — no egress allowance to `istio-system` is shipped or mentioned. Sidecars come up 2/2 but never get certs; STRICT mTLS fails for everything, and the "NetworkPolicy + mesh defense-in-depth" lesson silently becomes "these two controls break each other." **Fix:** ship and *teach* an `allow-egress-to-istiod` policy — a great lesson for this persona ("open the L4 path for the mesh control plane, same as any management plane").

10. **[BLOCKER] WebAuthn passkey lab runs over plain HTTP — physically can't work.** `labs/d1-keycloak-sso-mfa.md` Part C drives passkey registration at `http://keycloak.oss500.local:8080`; a plain-HTTP non-`localhost` origin is not a browser secure context, so `navigator.credentials.create` is unavailable and both the passwordless observable and the RP-ID-mismatch exercise are unreachable. The note (`identity-provider.md`) even teaches this exact failure mode, then the lab commits it. **Fix:** front Keycloak with TLS for Part C, or port-forward to literal `localhost` with RP ID = `localhost`, and say which.

11. **[BLOCKER] Cert-issuer lifecycle: Day 4 teardown deletes the ClusterIssuer Day 6 needs.** Phase 2 plan Day 4 ends with `certs/down.sh` (deletes cert-manager + all issuers including the hand-built `oss500-ca-issuer`); Day 6 ingress-WAF hard-requires `oss500-ca-issuer` but the plan gives Day 6 no certs bring-up block, and `certs/up.sh` ships a *differently named* `ca-issuer`. Day 6 step 2's Certificate sits `Ready=False` forever. **Fix:** add a Day 6 bring-up block (`certs/up.sh` + re-apply the issuer chain), or retarget the lab to the shipped `ca-issuer`.

12. **[BLOCKER] SIEM hands-on spine is broken at three points.** (a) The mounted `lab-infra/siem/config/ossec.conf` is a *study excerpt* (only `<remote>`/`<command>`/`<active-response>`, no `<ruleset>`) that replaces the manager's whole config at boot — so analysisd loads no decoders/rules, rule 5710 never fires, 100100 never correlates, and Parts B–E produce zero alerts with zero errors. (b) The lab says `ssh baduser@localhost` "on the agent," but the agent container has no sshd/ssh client and no `NET_ADMIN` cap, so neither the brute-force telemetry nor the `firewall-drop` active-response can occur. (c) The Sigma rule still uses deprecated v1 aggregation (`| count() by src_ip > 5`) that current pySigma refuses to convert, with a `-p sysmon`/`ecs_windows` pipeline on a linux/sshd rule (see Part 2). **Fix:** ship a complete `ossec.conf`, add `cap_add: [NET_ADMIN]` + a crafted-log or sshd-sidecar path with exact file/line format, and simplify the Sigma rule to a `-p`-less keyword selection. Verify one alert end-to-end before marking the lab valid.

13. **[BLOCKER] The "provisioned OSS-500 posture dashboard" is still not shipped.** `labs/d4-observability.md` Part D opens a Grafana dashboard "already loaded via the sidecar," but no `grafana_dashboard`-labelled ConfigMap exists and `up.sh` applies none — the sidecar was enabled without shipping the dashboard, so the prior audit's finding looks fixed but isn't. The metrics→logs→traces drill-down deliverable is undoable. **Fix:** commit the four-panel dashboard ConfigMap and apply it in `up.sh`, or reword Part D to "build these panels in Explore."

---

## Part 4 — Sequencing inversions and structural gaps

1. **[JUMP] OTel is used in Domain 3 but taught in Domain 4.** `domains/3-compute-ai/ai-security.md` `ai-observability` reasons over spans and `gen_ai.*` attributes (with a Python `start_as_current_span` snippet) a full domain before `observability.md` `obs-traces` defines span/trace/`traceparent`. **Fix:** a five-line span primer in the D3 section, or move the OTel-concepts slice of `observability.md` ahead of D3.

2. **[JUMP] `governance.md#gov-compliance` defers forward to a Phase-4 note.** It punts all Kubescape-scoring mechanics to `domains/4-posture-monitoring/vulnerability-posture.md` ("Read them there") — a note the learner reaches weeks later. A D1 quiz on how the score is computed is unanswerable from D1 material. **Fix:** inline the two or three scoring facts `gov-compliance` needs.

3. **[JUMP] `ztna-access-models.md` is a lobby, not a note.** ~32 lines (a five-model table + one PDP/PEP sentence) is the *sole* "notes read" prerequisite for **four build-it-yourself Terraform labs**, none of whose tool object models are taught anywhere (Boundary's scope→auth-method→host-catalog→target→role chain; OpenZiti identities/policies/enrollment; Pomerium routes+policy schema; NetBird groups/setup-keys/policies). Each lab quietly outsources this to vendor provider docs — the exact "which reference is necessary?" complaint. **Fix:** per-model subsections teaching the resource chain each lab builds (the Boundary lab's front-loaded-Vault box is the house style to copy).

4. **[JUMP] garak/PyRIT tooling required by two tracks, with no scaffolding — PyRIT gets none.** `d5-ai-redteam` and `d6-validate` both say "script a multi-turn PyRIT orchestrator" with only a GitHub link; the garak REST-generator JSON format (`-G localhost-ollama.json`) is never shown (one reference-solution command line partly rescues garak). For the persona's stated weak spot (LLM red-team tooling), these are leave-the-curriculum tasks despite strong Python. **Fix:** ship a ~20-line PyRIT orchestrator skeleton and a working garak generator-config example in `lab-infra/offense/`, referenced from the notes.

5. **[FRICTION] SPIRE walkthrough→operate transition needs one explicit flag.** D1 `wi-spiffe` is walkthrough-only (no server runs); D6 `d6-identity` is the first live SPIRE. The D6 intro is honest about it, but the note should state plainly: "D1 gave you no SPIRE muscle memory — this is the first and only place it runs; lean on the SVID≈short-lived-cert analogy." (Plan-level contradiction from the prior audit appears resolved: `plan/phase6` now says SPIRE *is* deployed by `lab-infra/agentic`.)

6. **[JUMP] Day-6 oversubscription in the two heaviest phases.** Phase 1 Day 6 schedules four ZTNA labs (each self-estimated 2–3h, with heavy per-lab infra — Boundary+Vault dev servers, OpenZiti controller+two tunnelers, a full NetBird compose stack *including a Zitadel IdP*, Pomerium re-standing Keycloak) into two 2-hour blocks — 8–12h of work in 4h, atop the persona's first-ever from-scratch HCL authoring (P4). Checkpoint-1 has zero ZTNA questions, so the gate doesn't require all four. Phase 2 Day 6 similarly stacks two 2–3h labs plus an unbudgeted certs/issuer rebuild into ~6.5h. **Fix:** designate **one** required broker (Pomerium — smallest infra, reuses Keycloak, reinforces OIDC) and mark the other three walkthrough-eligible in the plan/tracker (the honest pattern already used for `wi-spiffe`/`pam-approval`), or split the day.

7. **[JUMP] Model supply chain is absent from the phase that signs container images.** D3 pulls `llama3.2:1b` from Ollama's registry with zero provenance/hash/signing discussion; OWASP **LLM03** (data/model poisoning) and **LLM05** (supply chain), plus malicious model-format risks, appear nowhere — an ironic gap in the same phase that teaches cosign image signing. For the stated "AI security" outcome this is a real hole. **Fix:** a half-page "models are artifacts too" bridge in `supply-chain.md` or `ai-security.md` (pinning by digest, provenance, signed model artifacts).

---

## Part 5 — Phase 0 authoring on-ramps (close the substrate before Phase 1)

Phase 0 teaches *reading and running* but its own self-check and all of Phase 1 demand *writing*. Three cheap additions (~1 hour total) close it:

1. **First annotated manifest** — add one complete hardened pod YAML (`runAsNonRoot`/`runAsUser`/`readOnlyRootFilesystem`/`allowPrivilegeEscalation:false`/`drop:[ALL]`, limits, a probe) with `kubectl apply` + write-denied verification to `02-kubernetes.md`, and `kubectl get deploy nginx -o yaml` to read what the imperative command generated. Backs self-check #1 (P5) and Phase 1 Days 3/5.
2. **First `terraform apply`** — a 1h Day 3/4 block: a 10-line `main.tf` (kubernetes or kind provider) to create a namespace; `init` → read the `plan` diff → `apply` → inspect `terraform.tfstate` → `destroy`. Converts P4 and self-check #5 from recall to experience.
3. **RBAC preview has no backing content** — Day 4's 1.5h "RBAC preview" block points only at the full Phase-1 deep-dive; add a short "RBAC in 10 minutes" section to `02-kubernetes.md` or scope the plan line to specific intro sections.

Smaller Phase-0 items: name a concrete Helm chart for the "install one chart" block (e.g. podinfo); add the `docker run --user … --read-only --tmpfs` snippet the Day-1 hands-on assumes; add a 3-command namespaces/capabilities demo (`lsns`, `/proc/<pid>/ns`, `grep CapEff /proc/<pid>/status`) — the persona's weakest declared area is the one section with no runnable command; align the Phase-0 prereq list with lab-infra's baseline (add `jq`, Terraform); correct plan line 29 ("every later lab is Terraform-automated" → "the ZTNA labs are Terraform-automated").

---

## Suggested OpenSpec changes (prioritized)

Grouped so each maps to a scoped change touching the named capability spec(s).

**P0 — unblockers (student cannot proceed/verify from course materials):**
- `fix-psa-restricted-demo-namespace` → `lab-infrastructure` + `hands-on-labs`: the systemic admission-ordering blocker heading Part 3 — one demo-namespace change fixes the D1-governance, D3-pod-security, D3-runtime, and D3-supply-chain observables. **Highest learner-time-saved single change.**
- `fix-lab-correctness-blockers` → `hands-on-labs` + `lab-infrastructure`: Istio istiod-egress starvation (3.9), WebAuthn-over-HTTP (3.10), cert-issuer lifecycle (3.11), SIEM ossec.conf/agent/Sigma (3.12), Grafana dashboard (3.13), mesh principal (3.8). *(These overlap the plumbing domain of `persona-walkthrough-audit.md`; several are new or re-opened.)*
- `fix-note-lab-contradictions` → `hands-on-labs` + `oss-curriculum`: CNI/Calico story (Part 3.1), Sigma pipeline (3.2), PromQL example + metric (3.3), Loki→alert (3.4), Vault KV-v2 duality (3.5), WAF duplicate id (3.6), static-pod safety (3.7).
- `rank-learning-references` → extend `resource-citation`: per-link necessity tag + lint (Part 2). *This is the change that directly answers the stated complaint.*

**P1 — the used-before-taught primers (turn "intermediate + reference-dependent" into "expert + standalone"):**
- `add-rego-language-primer` → `oss-curriculum` (P1) — highest frequency.
- `add-oauth-oidc-jwt-primer` → new `0-fundamentals` note or D1.0 (P2).
- `add-llm-mechanics-primer` → new `0-fundamentals`/D3-preamble note (P3).
- `add-terraform-hcl-authoring-onramp` + `add-k8s-manifest-authoring-onramp` → `git-iac-foundation` / `oss-curriculum` + Phase-0 plan (P4, P5, Part 5).
- `add-mcp-protocol-primer` → `agentic-zero-trust` (P6).
- `fix-langgraph-reference-and-primer` → `agentic-zero-trust` (P7; also the wrong link).

**P2 — depth and structure:**
- `deepen-ztna-access-models-note` → `ztna-access-models` (Part 4.3).
- `add-ebpf-primer` → `oss-curriculum` (P8).
- `add-garak-pyrit-scaffolding` → `offensive-validation` + `lab-infrastructure` (Part 4.4).
- `fix-sequencing-inversions` → `oss-curriculum`: OTel D3-before-D4 (4.1), `gov-compliance` forward-ref (4.2), SPIRE signposting (4.5).

---

## What is genuinely well done (don't churn it in the fix pass)

- **The plan spine and gating.** Phase order, exam-weighted day budgets, flex-day-absorbs-slippage, "prove the control don't just deploy the tool," per-phase resource footprints — all correct and honest. Several prior-audit findings are visibly resolved (d2-fabric now sequenced as Phase 2 Day 7; Vault forward-dep and SPIRE plan-contradiction addressed; `TOOLS.md` exists and is thorough).
- **`04-linux-networking.md`** is the single best on-ramp in the repo for this persona (netns≈VPC, veth+bridge≈subnet, `ip route`≈route table, MASQUERADE≈NAT-gateway) — consider a one-line "if networking is your background, read this on day one" pointer, since it's currently deferred to Phase 2.
- **PKI/IDS/Python-strong topics are correctly self-contained:** `privileged-access` (SSH certs/TTLs), `keys-and-certificates` (transit/ACME/CRL-OCSP), `supply-chain` (cosign keyless ≈ CT logs), `kubernetes-rbac`, `network-detection` (Suricata/Zeek), `purple-team`, `ztna-authz`, and the infra attack-sim track. The course leverages his strengths deliberately and well.
- **`ai-security.md`** builds the LLM *threat model* from zero with worked NeMo/OPA/OTel snippets — strong given the material is new to the exam; its gap is the missing *mechanics* primer beneath it (P3), not the security teaching.
- **Reference citation quality** (deep links, scoped time estimates, `(reference)` marking) is already high and spec-governed — which is why the fix in Part 2 is a tag, not a rewrite.
