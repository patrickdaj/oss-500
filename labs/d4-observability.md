# Lab d4: Observability — metrics, logs, traces, dashboards, alerting

Stand up the open-source observability triad, then prove each signal fires: a PromQL alert that reaches Alertmanager, a LogQL query that finds a security event in Loki, and a trace that lands in Tempo — all correlated in one Grafana pane.

**Objectives covered**

| id | Objective |
|---|---|
| `obs-metrics` | Collect and query metrics |
| `obs-logs` | Aggregate and query logs |
| `obs-traces` | Capture distributed traces |
| `obs-dashboards` | Build monitoring dashboards |
| `obs-alerting` | Define alerting rules and routing |

**SC-500 correspondence**: Azure Monitor Metrics (Prometheus), Log Analytics (Loki), Application Insights (Tempo/OpenTelemetry), Azure Monitor Workbooks (Grafana), Azure Monitor alerts + action groups (Alertmanager).

**Prerequisites**
- kind cluster up + [`lab-infra/shared`](../lab-infra/shared/) applied (`kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml && lab-infra/shared/up.sh`).
- [`lab-infra/observability`](../lab-infra/observability/) up (`cd lab-infra/observability && cp grafana-admin.env.example grafana-admin.env && ./up.sh`).
- Notes read: [observability.md](../domains/4-posture-monitoring/observability.md).

**Estimated time**: 2–3 h · $0 (local)

> **Resource note:** the full observability stack (Prometheus + Grafana + Loki + Tempo + OTel Collector) is one of the two heaviest footprints in the course. **Run it alone** — tear down the SIEM, runtime, and AI stacks first. Budget ~4–5 GB RAM for this lab.

## Steps

### Part A — Metrics with Prometheus (`obs-metrics`)
1. Confirm the stack: `kubectl get pods -n oss500-monitoring` — Prometheus, Alertmanager, Grafana, Loki, Tempo, and the node/kube-state exporters are Running.
2. Port-forward Prometheus: `kubectl -n oss500-monitoring port-forward svc/oss500-kube-prometheus-stack-prometheus 9090:9090`. Open `http://localhost:9090`.
3. Run security-relevant PromQL in the expression browser:
   - `sum by (namespace) (kube_pod_info)` — pod count per namespace (spot sprawl).
   - `kube_pod_container_status_restarts_total > 0` — restarting containers.
   - `rate(apiserver_request_total{code=~"5.."}[5m])` — API-server error rate.
4. Prove target discovery is label-driven: **Status → Targets** shows the `ServiceMonitor`-selected endpoints. Look at [`prometheus-values.yaml`](../lab-infra/observability/prometheus-values.yaml) — no hand-edited `prometheus.yml`; scrape config is CRDs.

### Part B — Logs with Loki (`obs-logs`)
5. Grafana is at `http://localhost:8080` via ingress (or `kubectl -n oss500-monitoring port-forward svc/oss500-grafana 3000:80`). Log in with the admin creds from `grafana-admin.env`.
6. **Explore → Loki** data source. Generate a security-flavored log: deploy the noisy demo app that logs auth failures — `kubectl apply -f ../lab-infra/observability/demo-authlog.yaml -n oss500-apps`.
7. LogQL query: `{namespace="oss500-apps", app="authlog"} |= "Failed password"` — the brute-force lines appear.
8. Turn logs into a metric (the basis for a log alert): `sum(rate({namespace="oss500-apps", app="authlog"} |= "Failed password" [1m]))`. Note the rate climbs — you'll alert on this shape in Part E.

### Part C — Traces with OpenTelemetry + Tempo (`obs-traces`)
9. Deploy the instrumented demo that emits OTLP to the Collector: `kubectl apply -f ../lab-infra/observability/demo-traced-app.yaml -n oss500-apps`. It calls a downstream service so traces have child spans.
10. Generate traffic: `kubectl -n oss500-apps port-forward svc/traced-frontend 8000:8000` then `for i in $(seq 1 20); do curl -s localhost:8000/api >/dev/null; done`.
11. Grafana **Explore → Tempo → Search**: find recent traces, open one, and read the span tree (frontend → backend). The `traceparent` header propagation is what stitched them.
12. Inspect the pipeline in [`otel-collector.yaml`](../lab-infra/observability/otel-collector.yaml): receivers (OTLP) → processors (batch) → exporters (Tempo, plus Prometheus/Loki) — one Collector, three backends.

### Part D — Dashboards & correlation in Grafana (`obs-dashboards`)
13. Import the provisioned **OSS-500 posture dashboard** (already loaded via the sidecar; find it under Dashboards). Panels: API-server 5xx rate, pods-running-as-root count, denied/failed-auth log rate, trace latency.
14. Prove cross-signal drill-down: from the failed-auth panel (Loki), click through to the raw log lines; from a latency spike, jump to the Tempo trace. This metrics→logs→traces pivot is the "single pane" investigation.
15. Confirm Grafana stores nothing itself: `kubectl -n oss500-monitoring delete pod -l app.kubernetes.io/name=grafana`, wait for it to restart, reopen — the dashboards (provisioned JSON) and all data (in Prometheus/Loki/Tempo) survive.

### Part E — Alerting rules + routing (`obs-alerting`)
16. Review the alert rule in [`alert-rules.yaml`](../lab-infra/observability/alert-rules.yaml): a `PrometheusRule` firing `AuthFailureSpike` when the failed-auth rate crosses a threshold `for: 2m`, and `KubePodCrashLooping` from the bundled rules.
17. Trigger it: scale the authlog app so failures spike — `kubectl scale deploy/authlog -n oss500-apps --replicas=3`. Watch **Prometheus → Alerts**: `AuthFailureSpike` goes `Pending` (during `for:`) then `Firing`.
18. Watch routing: port-forward Alertmanager (`kubectl -n oss500-monitoring port-forward svc/oss500-kube-prometheus-stack-alertmanager 9093:9093`), open `http://localhost:9093` — the alert is grouped by `namespace`/`alertname` and routed to the `security` receiver (webhook) per [`alertmanager-config.yaml`](../lab-infra/observability/alertmanager-config.yaml).
19. Prove routing ≠ condition: add a silence in the Alertmanager UI for `alertname=AuthFailureSpike`; the rule still *fires* in Prometheus but delivery is muted — the two layers are independent.

## Verification
- **Metrics**: a PromQL query returns live cluster series and `ServiceMonitor` targets show `UP` in Prometheus.
- **Logs**: the LogQL query surfaces `Failed password` lines from Loki, and the rate query shows the spike.
- **Traces**: a multi-span trace (frontend→backend) is searchable in Tempo with correct parent/child spans.
- **Dashboards**: killing the Grafana pod loses no data or dashboards (proves Grafana is stateless viz).
- **Alerting**: `AuthFailureSpike` transitions Pending→Firing in Prometheus **and** appears grouped/routed in Alertmanager; a silence mutes delivery without stopping the rule. *(This fired-alert-reaching-Alertmanager is the observable proof.)*

## Teardown
- `kubectl delete -f ../lab-infra/observability/demo-authlog.yaml -f ../lab-infra/observability/demo-traced-app.yaml -n oss500-apps`
- `cd lab-infra/observability && ./down.sh`

## What the exam asks
- Prometheus **pulls** metrics from `/metrics`; it doesn't receive pushes (Pushgateway is only for batch jobs). Metrics ≠ logs — high-cardinality data belongs in Loki.
- Loki indexes **labels, not content**; LogQL can derive metrics from logs. It's cheaper than Elastic but not a full-text engine — know Loki vs OpenSearch trade-offs.
- Traces answer **"where in the call graph"**; the OTel Collector is a deploy-once fan-out (OTLP in, Tempo/Prometheus/Loki out).
- Grafana **stores nothing** — it's visualization/correlation over the backends; dashboards live as JSON in Git.
- Alert **rule/condition (Prometheus) vs routing/delivery (Alertmanager)** are separate. `for:` prevents flapping; grouping/inhibition/silences are distinct routing behaviors. "Fires but no page" = routing bug, not a rule bug.
