# Tasks — fix-note-lab-contradictions

## 1. CNI enforcement story (3.1)

- [x] 1.1 Rewrite `network-security.md` (§ segment east-west) to match the lab: kindnet enforces Part A, Calico optional/manual; drop the "installs Calico" claim.

## 2. Sigma pipeline (3.2)

- [x] 2.1 In `labs/d4-siem-wazuh.md` Part C, teach `sigma list pipelines` and name the correct opensearch/linux pipeline for the linux/sshd rule.
- [x] 2.2 Correct the reference command in the lab and in `siem-incident-response.md` `siem-detect` (remove `-p ecs_windows`).

## 3. PromQL primer + example (3.3)

- [x] 3.1 Add an instant-vs-range-vector + vector-matching (`on(...) group_left`) primer inline in `observability.md` `obs-alerting`.
- [x] 3.2 Repair the garbled `… unless kube_pod_container_status_running` expression.
- [x] 3.3 Confirm `kube_pod_spec_containers_security_context_privileged` is exposed by the lab's kube-state-metrics; if not, switch the example to an exposed metric.

## 4. Log-derived-metric transition (3.4)

- [x] 4.1 Add one paragraph to `obs-alerting` on the Loki-ruler / log-derived-metric mechanism so the Part B LogQL → Part E Prometheus alert transition is coherent.

## 5. Vault KV-v2 dualities (3.5)

- [x] 5.1 Add one paragraph on KV-v2 `data/` path duality to `secrets-management.md` `vault-access`.
- [x] 5.2 Add one paragraph on KV-v2-vs-dynamic response shape plus a two-line Go-template primer to `vault-k8s`; align `labs/d2-vault-k8s-injection.md` template syntax.

## 6. WAF config (3.6)

- [x] 6.1 Collapse the `labs/d2-ingress-waf.md` Part C reference to the note's single combined `SecAction` (remove the duplicate `id:900110`).
- [x] 6.2 Add a minimal `SecRule ARGS "@rx …" "id:…,phase:2,deny"` example or mark custom-rule authoring beyond-lab in `waf-rules`.

## 7. Static-pod safety net (3.7)

- [x] 7.1 Add 4–6 sentences to `data-protection.md` `data-encrypt` on static pods, the kubelet manifest-watch, and apiserver recovery (`docker exec` + revert).

## 8. Validation

- [x] 8.1 Run `openspec validate fix-note-lab-contradictions --type change --strict`.
