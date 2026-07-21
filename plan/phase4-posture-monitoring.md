# Phase 4 — Posture & monitoring

Domain 4 is **20–25%** of SC-500 and the observability/detection/posture backbone of a security program: collect telemetry, run a SIEM and respond to incidents, detect threats on the network, and manage vulnerabilities and posture. This phase is the last domain milestone before review — by its checkpoint you should be able to fire an alert to Alertmanager, match a Sigma detection in Wazuh/OpenSearch, hunt with the Query DSL, trip a Suricata signature, and watch a Kubescape compliance score rise after remediation.

Notes live in [`domains/4-posture-monitoring/`](../domains/4-posture-monitoring/); labs in [`labs/`](../labs/); lab environments in [`lab-infra/`](../lab-infra/). **Resource discipline is critical here:** the full observability stack and the Wazuh + OpenSearch SIEM are the two heaviest footprints in the course — **run each alone**, and never the same day on the reference host. Tear down every component with its `down.sh` before the next block.

## Day 1 — Metrics & logs (Prometheus, Loki)

- [ ] **[2h] Read observability notes: metrics + logs** — [observability.md](../domains/4-posture-monitoring/observability.md) sections `obs-metrics`, `obs-logs`. Prometheus pull model, ServiceMonitor/PodMonitor, PromQL `rate()`/`sum by`; Loki labels-not-content, LogQL, log-derived metrics. Map to Azure Monitor Metrics / Log Analytics + KQL.
- [ ] **[2h] Bring up the observability stack** — [`lab-infra/observability`](../lab-infra/observability/) (`cp grafana-admin.env.example grafana-admin.env`, `./up.sh`). **Run it alone.** Explore Prometheus targets and run the security PromQL from [d4-observability](../labs/d4-observability.md) Part A.
- [ ] **[1.5h] Lab Part B — logs in Loki** — deploy the authlog demo, query `Failed password` with LogQL, and turn it into a rate. This is the log-based-alert foundation.
- [ ] **[0.5h] Quiz + note** — attempt `q4-01`–`q4-04` from [quiz-4](../assessment/data/quiz-4.yaml); jot the Loki-vs-OpenSearch trade-off in your own words. Leave the stack up for Day 2.

## Day 2 — Traces, dashboards, alerting (Tempo/OTel, Grafana, Alertmanager)

- [ ] **[2h] Read observability notes: traces + dashboards + alerting** — `obs-traces`, `obs-dashboards`, `obs-alerting`. OTel Collector fan-out, Tempo, spans; Grafana as stateless correlation; rule (Prometheus) vs route (Alertmanager), `for:`, grouping/inhibition/silences.
- [ ] **[2h] Lab Parts C–D — traces + correlation** — deploy the traced app, generate traffic, read the span tree in Tempo, and prove the metrics→logs→traces drill-down in Grafana. Kill the Grafana pod to prove it's stateless.
- [ ] **[2h] Lab Part E — fire an alert to Alertmanager** — trip `AuthFailureSpike` (Pending→Firing), watch grouping/routing in Alertmanager, then add a silence to prove routing ≠ condition. **This fired-alert-reaching-Alertmanager is the observable.**
- [ ] **[0.5h] Teardown** — `cd lab-infra/observability && ./down.sh`; confirm the namespace is empty. Free the RAM before the SIEM.

## Day 3 — SIEM: deploy, collect, detect (Wazuh + OpenSearch, Sigma)

- [ ] **[2h] Read SIEM notes** — [siem-incident-response.md](../domains/4-posture-monitoring/siem-incident-response.md) sections `siem-deploy`, `siem-collect`, `siem-detect`. Two-tier SIEM, decoders/normalization before detection, Sigma detection-as-code and conversion to backend queries. Map to Sentinel / connectors / analytics rules.
- [ ] **[2h] Stand up the SIEM — ALONE** — [`lab-infra/siem`](../lab-infra/siem/) (`cp .env.example .env` with strong creds, set `vm.max_map_count`, `./up.sh`). **Nothing else running.** Log into the dashboard with non-default creds ([d4-siem-wazuh](../labs/d4-siem-wazuh.md) Part A).
- [ ] **[2h] Lab Parts B–C — collect + detect** — onboard an agent, generate SSH brute force, confirm the alert has *parsed* fields (normalization), then convert `sigma/ssh-bruteforce.yml` to an OpenSearch query and flag the events. Keep the stack up for Day 4.

## Day 4 — SIEM hunting & response + network detection (OpenSearch DSL, Wazuh active response, Suricata, Zeek)

- [ ] **[2h] Read SIEM hunt/response + network notes** — `siem-hunt`, `siem-response`, then [network-detection.md](../domains/4-posture-monitoring/network-detection.md) (`nid-suricata`, `nid-zeek`). DSL `bool`+aggregations ≈ KQL `summarize by`; active-response guardrails; IDS vs IPS; Zeek behavioral logs.
- [ ] **[2h] Lab Parts D–E — hunt + automated response** — run the OpenSearch DSL aggregation to surface the attacking IP, then trip active response and watch `firewall-drop` block the IP and auto-revert after the timeout. **Then tear the SIEM down** (`./down.sh -v`) to reclaim RAM.
- [ ] **[2h] Network detection lab** — [d4-network-detection](../labs/d4-network-detection.md) with [`lab-infra/network-detection`](../lab-infra/network-detection/) `./up.sh`; `suricata-update`; fire the `testmynids.org` signature and confirm the `event_type:"alert"` in `eve.json`; read the same request behaviorally in Zeek's `http.log`/`conn.log`. `./down.sh`.
- [ ] **[0.5h] Quiz** — `q4-11`–`q4-24` (SIEM + network). Note any misses for the flex day.

## Day 5 — Vulnerability & posture (Kubescape, kube-bench, Trivy)

- [ ] **[2h] Read posture notes** — [vulnerability-posture.md](../domains/4-posture-monitoring/vulnerability-posture.md) all four objectives. Posture (config) vs vulnerability (CVE) scanning; CIS/kube-bench + shared responsibility; framework compliance %/secure score; risk-based prioritization.
- [ ] **[2h] Posture lab Parts A–D** — [`lab-infra/posture`](../lab-infra/posture/) `./up.sh`; deploy the insecure demo into `oss500-security`; Kubescape posture scan; kube-bench CIS audit; produce an NSA compliance report and record the baseline score. ([d4-vuln-posture](../labs/d4-vuln-posture.md).)
- [ ] **[2h] Posture lab Part E — prioritize, remediate, prove the delta** — Trivy the demo image, prioritize by severity × fixability × exposure, apply `secure-demo.yaml` (patched + hardened), re-scan, and **watch the compliance score rise**. That improvement is the observable. `./down.sh`.
- [ ] **[0.5h] Quiz** — `q4-25`–`q4-31` (posture). 

## Day 6 — Flex, weak-spot review, and Checkpoint 4

- [ ] **[1.5h] Catch-up / slippage** — finish any unrun lab section (walkthrough the SIEM active-response or network detection at depth if a host constraint blocked it). Slippage from Days 1–5 lands here, not in Review.
- [ ] **[1.5h] Weak-spot review** — re-read notes for any objective whose quiz questions you missed; filter the tracker for confidence 1 in `d4`.
- [ ] **[1h] Full teardown check** — confirm every Phase 4 component is down: `kubectl get all -A -l app.kubernetes.io/part-of=oss500` and `docker compose -p oss500 ps` both empty. Leftover SIEM containers are the #1 overnight resource killer.
- [ ] **Rest** — take your day off this week before Review.

## Checkpoint

Take **[checkpoint-4](../assessment/checkpoint-4.md)** (bank: [quiz-4](../assessment/data/quiz-4.yaml), pass ≥ 80%) in test mode on this flex day. Every d4 subsection is represented — observability (metrics/logs/traces/dashboards/alerting), SIEM & IR (deploy/collect/detect/hunt/response), network detection (Suricata/Zeek), and vulnerability/posture (Kubescape/kube-bench/Trivy).

- Score **< 80%** → this flex day's remaining time goes to remediation: each missed question maps to `objectiveIds`; re-read that note section and re-run its lab step before moving to Review.
- Score **≥ 80%** with every d4 objective at confidence ≥ 2 (notes read, lab performed) → Domain 4 is green. Proceed to the [Review & capstone](review.md) phase, where the SIEM and observability stacks reappear in the integrated identity → workload → detection → SIEM chain.
