## Why

A senior engineer reads the prerequisite note *before* the lab and stops the moment the note contradicts the lab it prepares — or demands a skill the note never taught. Seven such note-vs-lab contradictions strand a careful reader. These are teaching-correctness bugs (note ↔ lab disagreement), distinct from the shipped-infra blockers in `fix-lab-correctness-blockers` and the systemic PSA issue in `fix-psa-restricted-demo-namespace`.

- **3.1 CNI enforcement story is self-contradictory** — `domains/2-secrets-data-networking/network-security.md` says "this course **installs Calico**… kindnet's support is limited"; the lab `labs/d2-network-policy.md` and `lab-infra/network/up.sh` say no CNI is installed, kindnet enforces Part A, Calico is optional. For a segmentation specialist, ambiguity about whether the policy is even enforced is disqualifying.
- **3.2 Sigma conversion step is uncompletable from course materials** — `labs/d4-siem-wazuh.md` Part C step 9 demands the correct `-p` pipeline for a `product: linux, service: sshd` rule, never names one, and the reference solution shows `-p ecs_windows` (a Windows pipeline) then parenthetically says "use the linux pipeline"; `siem-incident-response.md` models the same wrong command.
- **3.3 PromQL flagship example exceeds what the note teaches** — `domains/4-posture-monitoring/observability.md` `obs-alerting` uses `* on(namespace,pod) group_left` (vector matching, taught nowhere) and contains a garbled `… unless kube_pod_container_status_running` expression; a zero-Prometheus learner cannot parse the note's headline security alert from the note. (Also: verify `kube_pod_spec_containers_security_context_privileged` is actually exposed by the lab's kube-state-metrics — it likely isn't, which would make the query return empty.)
- **3.4 Loki→alert bait-and-switch** — the observability lab builds the detection as a LogQL rate (Part B), then Part E's reference alert silently switches to a Prometheus counter (`authlog_failed_logins_total`); the Loki-ruler / log-derived-metric mechanism is never taught, so a learner following Part B writes a non-evaluating `PrometheusRule`.
- **3.5 Vault KV-v2 path & template dualities** — `secrets-management.md` grants `secret/data/app/*` in policy but uses `secret/app/...` in every CLI example without explaining KV-v2's `data/` infix; the injector section uses `{{ .Data.username }}` while `labs/d2-vault-k8s-injection.md` uses `{{ .Data.data.username }}`. Both are canonical first-Vault tripwires that land on "your turn" scaffolds.
- **3.6 WAF duplicate `id:900110` + untaught custom rules** — `labs/d2-ingress-waf.md` Part C reference uses two `SecAction` directives with the same `id:900110` (ModSecurity rejects duplicate IDs → config-load error), and `waf-rules` puts custom `SecRule` authoring in exam scope while neither note nor lab shows `SecRule` anatomy.
- **3.7 Static-pod surgery with no safety net** — `labs/d2-data-protection.md` Part A has the learner hand-edit `/etc/kubernetes/manifests/kube-apiserver.yaml` on the node; static pods, kubelet's manifest-watch, and recovery-when-apiserver-won't-return are taught nowhere.

## What Changes

- **3.1** — make the note match the lab: kindnet enforces Part A, Calico optional/manual.
- **3.2** — teach `sigma list pipelines`, name the correct opensearch/linux pipeline, and correct both the lab reference and `siem-incident-response.md`.
- **3.3** — add an instant-vs-range-vector + vector-matching primer inline in `obs-alerting`, repair the broken expression, and confirm the privileged-pod metric is exposed (or switch to one that is).
- **3.4** — one paragraph in `obs-alerting` on the log-derived-metric / Loki-ruler mechanism so the Part B→Part E transition is coherent.
- **3.5** — one paragraph on KV-v2 path duality (`vault-access`) plus one on KV-v2-vs-dynamic response shape and a two-line Go-template primer (`vault-k8s`).
- **3.6** — collapse the WAF reference to the note's single combined `SecAction`; add a minimal `SecRule ARGS "@rx …" "id:…,phase:2,deny"` example or mark custom-rule authoring beyond-lab.
- **3.7** — 4–6 sentences in `data-protection.md` `data-encrypt` on static pods, the kubelet manifest-watch, and recovery (no `kubectl`; `docker exec` + revert).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `oss-curriculum` — adds one requirement per note-vs-lab fix so each is independently verifiable: the note's enforcement story matches the lab (CNI/Calico), the note teaches its flagship PromQL constructs, the note connects the log-derived metric to the alert, the note teaches Vault KV-v2 path/template duality, and the note teaches static-pod safety/recovery.
- `hands-on-labs` — adds one requirement per lab-reference fix: the Sigma conversion names a correct pipeline, and the WAF reference configuration loads without a duplicate-id error.

## Impact

- Affected specs: `oss-curriculum` (five ADDED requirements), `hands-on-labs` (two ADDED requirements).
- Affected content (at implementation time): `domains/2-secrets-data-networking/network-security.md`, `secrets-management.md`, `domains/4-posture-monitoring/observability.md`, `siem-incident-response.md`, `data-protection.md`; `labs/d4-siem-wazuh.md`, `labs/d2-ingress-waf.md`, `labs/d2-vault-k8s-injection.md`, `labs/d2-data-protection.md`.
- Unblocks a careful reader who reads the note first, across the segmentation, SIEM/Sigma, observability/PromQL, Vault, WAF, and data-protection labs.
