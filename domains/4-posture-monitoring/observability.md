# Collect metrics, logs, and traces for security monitoring

Domain 4, subsection 1 (`d4-observability`). Security monitoring starts with telemetry: you cannot detect, alert on, or investigate what you never collected. This subsection builds the open-source observability triad — **metrics** (Prometheus), **logs** (Loki), and **traces** (Tempo/OpenTelemetry) — visualized in **Grafana** and made actionable by **Alertmanager**. It is the OSS analogue of the Azure Monitor family: Azure Monitor Metrics, Log Analytics, Application Insights, Workbooks, and Azure Monitor alerts. Primary lab: [d4-observability](../../labs/d4-observability.md) on the [`lab-infra/observability`](../../lab-infra/observability/) stack (kube-prometheus-stack + Loki + Tempo + an OpenTelemetry Collector).

## Collect and query metrics

*Objective: `obs-metrics` · OSS: Prometheus ≈ SC-500: Azure Monitor · Lab: [d4-observability](../../labs/d4-observability.md)*

Prometheus is a **pull-based** time-series database: a scrape loop hits each target's `/metrics` HTTP endpoint on an interval and stores the samples, each identified by a metric name plus a set of key/value **labels** (`http_requests_total{code="500",job="api"}`). In Kubernetes the Prometheus Operator (shipped by the `kube-prometheus-stack` Helm chart) turns scrape config into custom resources — `ServiceMonitor` and `PodMonitor` select targets by label, so you never hand-edit `prometheus.yml`. Node and cluster security signals arrive out of the box: `node-exporter` (host CPU/mem/disk/filesystem), `kube-state-metrics` (object state — e.g. a pod running as privileged), and cAdvisor (per-container usage).

You query with **PromQL**. Security-relevant examples: `rate(apiserver_request_total{code=~"5.."}[5m])` for API-server error spikes, `kube_pod_container_status_restarts_total` climbing on a workload (possible crash-loop from a killed exploit), or `count(kube_pod_info) by (namespace)` to spot unexpected pod sprawl. PromQL's `rate()`, `increase()`, aggregation operators (`sum by`, `count by`), and label matchers (`=`, `!=`, `=~`, `!~`) are the core you must read fluently.

The SC-500 mapping: Prometheus ≈ **Azure Monitor Metrics**, `ServiceMonitor`/`PodMonitor` ≈ the Azure Monitor managed Prometheus scrape config / DCRs, and PromQL ≈ the metrics query experience. Azure Monitor managed Prometheus is literally Prometheus-compatible — Microsoft ships a managed Prometheus that ingests the same exposition format and queries with PromQL — so this is one of the tightest OSS↔Azure equivalences in the whole curriculum.

Exam gotchas:
- Prometheus **pulls**; it does not receive pushes (the Pushgateway is only for short-lived batch jobs, and is an anti-pattern for service metrics). "Configure the app to push metrics to Prometheus" is wrong.
- Prometheus is for metrics (numeric time series), **not** logs. High-cardinality data (user IDs, request IDs, full URLs) as labels will blow up memory — that belongs in Loki, not a Prometheus label.
- Local Prometheus storage is not long-term/HA; Thanos or Mimir (or Azure Monitor managed Prometheus) handle durable, multi-cluster retention. Recognize them as the "long-term metrics" answer.

**Resources:**
- [Prometheus overview](https://prometheus.io/docs/introduction/overview/) (~15 min)
- [Querying basics (PromQL)](https://prometheus.io/docs/prometheus/latest/querying/basics/) (~20 min)
- [Prometheus Operator ServiceMonitor design](https://prometheus-operator.dev/docs/user-guides/getting-started/) (~15 min)

## Aggregate and query logs

*Objective: `obs-logs` · OSS: Loki ≈ SC-500: Log Analytics · Lab: [d4-observability](../../labs/d4-observability.md)*

Grafana **Loki** is a log-aggregation system deliberately modeled on Prometheus: it indexes only a small set of **labels** per stream (namespace, pod, container, app) and stores the raw log lines compressed in object storage, rather than full-text indexing every field like Elasticsearch/OpenSearch. That makes it cheap to run but shifts filtering into query time. A collector — **Promtail**, Grafana **Alloy**, or an OpenTelemetry Collector — tails pod stdout/stderr and ships lines to Loki with Kubernetes metadata attached as labels.

You query with **LogQL**. A LogQL query is a label selector (the "stream selector") followed by optional line/label filters and, optionally, a metric aggregation: `{namespace="oss500-apps"} |= "Failed password" | json | line_format "{{.msg}}"` finds SSH brute-force lines, and `sum(rate({namespace="oss500-security"} |= "denied" [5m])) by (pod)` turns log matches into a rate you can alert on. That last form — LogQL over logs producing a time series — is how you build **log-based alerts** without a separate SIEM.

SC-500 mapping: Loki ≈ **Azure Monitor Logs / Log Analytics workspace**, the collector ≈ the Azure Monitor Agent + Data Collection Rules, and LogQL ≈ **KQL** (though KQL is far richer — Loki is filter-and-aggregate, KQL is a full analytics language). Both centralize logs so detections and hunts run against one store; in this course the heavier full-text hunting store is OpenSearch under the SIEM (`siem-hunt`), while Loki is the lightweight operational-log tier.

Exam gotchas:
- Loki indexes **labels, not content** — over-labeling (e.g. a label per request ID) creates high cardinality and kills performance, the same failure mode as Prometheus labels.
- Loki ≠ Elasticsearch: no per-field inverted index, so "full-text search across everything instantly" is an OpenSearch/Elastic strength, not Loki's. Know when a scenario wants Loki (cheap, label-scoped) vs OpenSearch (rich hunting).
- LogQL can produce metrics from logs (`rate`, `count_over_time`) — useful when you have no metric for an event but do have the log line.

**Resources:**
- [Loki fundamentals & architecture](https://grafana.com/docs/loki/latest/get-started/) (~15 min)
- [LogQL log query language](https://grafana.com/docs/loki/latest/query/) (~20 min)

## Capture distributed traces

*Objective: `obs-traces` · OSS: Tempo / OpenTelemetry ≈ SC-500: Application Insights · Lab: [d4-observability](../../labs/d4-observability.md)*

A **distributed trace** follows one request across services: a root **span** (the incoming request) with child spans for each downstream call, all sharing a **trace ID** propagated in headers (W3C `traceparent`). This is how you answer "which of the eight services made this request slow" — and, for security, how you attribute a suspicious call chain, follow lateral movement between microservices, or tie an anomalous auth event to the exact downstream data access it triggered. Grafana **Tempo** is the trace backend; it indexes by trace ID and (with TraceQL) span attributes, storing spans cheaply in object storage.

**OpenTelemetry (OTel)** is the vendor-neutral instrumentation standard — SDKs plus the **OpenTelemetry Collector**, a pipeline of receivers → processors → exporters. Apps emit OTLP (the OpenTelemetry protocol) to the Collector, which batches/enriches and fans out: traces to Tempo, metrics to Prometheus, logs to Loki. OTel is the single most important convergence point in modern observability — one instrumentation, many backends — and it is exactly what the AI-security objective `ai-observability` reuses to audit LLM calls.

SC-500 mapping: Tempo + OTel ≈ **Application Insights** (distributed tracing, the application map), OTLP ≈ the Application Insights/Azure Monitor OpenTelemetry Distro (Azure Monitor natively ingests OTLP now), and TraceQL ≈ transaction search / the end-to-end transaction view. Microsoft's recommended path into Application Insights is the OpenTelemetry Distro, so the instrumentation skill transfers directly.

Exam gotchas:
- Traces answer **"where in the call graph,"** metrics answer **"how much/how often,"** logs answer **"what exactly happened."** A scenario asking to pinpoint which service in a chain introduced latency or an unexpected call → traces, not metrics.
- The **Collector** is a deploy-once fan-out point; you do not need a separate agent per backend. "Send OTLP to the Collector, it routes to Tempo/Prometheus/Loki" is the modern pattern.
- **Sampling**: head vs tail sampling controls trace volume/cost. Tail-based sampling (keep the interesting/erroring traces) is the answer when "keep failed traces but drop the noise."

**Resources:**
- [OpenTelemetry — what is OpenTelemetry](https://opentelemetry.io/docs/what-is-opentelemetry/) (~15 min)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) (~15 min)
- [Grafana Tempo introduction](https://grafana.com/docs/tempo/latest/introduction/) (~15 min)

## Build monitoring dashboards

*Objective: `obs-dashboards` · OSS: Grafana ≈ SC-500: Azure Monitor Workbooks · Lab: [d4-observability](../../labs/d4-observability.md)*

**Grafana** is the visualization and correlation layer over every backend above: add Prometheus, Loki, and Tempo as **data sources**, then build **dashboards** of panels (time series, stat, table, logs, heatmap) each backed by a PromQL/LogQL/TraceQL query. For a security SOC you build a posture dashboard: API-server 5xx rate, pods running as root (from `kube-state-metrics`), denied-request logs from Loki, and a drill-down from a metric spike straight into the correlated log lines and the trace — the **metrics→logs→traces** correlation that makes an investigation fast. Dashboards are JSON and should live in Git (provisioned via ConfigMap/sidecar), which is itself the `gov-iac` discipline applied to monitoring.

The killer feature for incident response is cross-signal linking: a Grafana **exemplar** or a data-source-linked panel jumps from a latency spike (metric) to the exact trace ID (Tempo) and the pod's logs (Loki) at that timestamp — one pane, three signals. That is what "single pane of glass" actually means operationally.

SC-500 mapping: Grafana dashboards ≈ **Azure Monitor Workbooks** (and Azure Managed Grafana is a first-party Azure service — Microsoft literally offers hosted Grafana), Grafana data sources ≈ Workbook data sources across Metrics/Logs/Resource Graph, and Grafana alerting overlaps Azure Monitor alerts. Provisioned dashboard JSON ≈ Workbook ARM templates.

Exam gotchas:
- Grafana is **visualization/query**, not storage — it holds no metrics or logs itself; killing Grafana loses no data. "Grafana went down, did we lose logs?" → no, the data is in Loki/Prometheus.
- Dashboards belong in source control (JSON, provisioned), not click-configured and forgotten — the IaC theme.
- Grafana **datasource permissions and org/folder RBAC** matter: a read-only viewer role vs an editor is an access-control question, and Grafana can front-authenticate via OIDC (Keycloak from `d1`).

**Resources:**
- [Grafana dashboards — get started](https://grafana.com/docs/grafana/latest/getting-started/build-first-dashboard/) (~20 min)
- [Grafana data source management](https://grafana.com/docs/grafana/latest/administration/data-source-management/) (~10 min)

## Define alerting rules and routing

*Objective: `obs-alerting` · OSS: Alertmanager ≈ SC-500: Azure Monitor alerts · Lab: [d4-observability](../../labs/d4-observability.md)*

An alert has two halves. **Rule evaluation** lives in Prometheus (or Grafana): a PromQL expression that, when true for a `for:` duration, produces a firing alert with labels and annotations — e.g. `alert: KubePodCrashLooping` on `rate(kube_pod_container_status_restarts_total[15m]) > 0 for: 15m`. **Routing** lives in **Alertmanager**: it deduplicates, groups (by cluster/namespace/alertname so one incident isn't 50 pages), applies **inhibition** (suppress the warning when the critical for the same target is already firing), respects **silences** (planned maintenance), and dispatches to receivers (email, Slack, PagerDuty, generic webhook) chosen by a routing tree that matches on alert labels — e.g. `severity: critical` → PagerDuty, `team: security` → the SOC channel.

The security lens: alerting turns raw telemetry into an actioned signal. A default-deny NetworkPolicy violation logged in Loki, a Falco alert rate from `d3`, or an API-server error spike all become a routed, deduplicated, escalatable page. The rule/route split is the exam-critical concept — the *condition* and the *delivery* are separate systems, tuned separately.

SC-500 mapping: Prometheus/Grafana rules ≈ **Azure Monitor alert rules** (metric, log, and activity-log alerts), and Alertmanager ≈ **action groups + alert processing rules** (grouping, suppression during maintenance, routing to email/SMS/webhook/Logic App). Alertmanager silences ≈ alert processing rules that suppress during a maintenance window; inhibition ≈ suppressing dependent alerts.

Exam gotchas:
- **Rule (condition) vs route (delivery) are separate**: "the alert fires but nobody is paged" → the rule is fine, the Alertmanager route/receiver is misconfigured. Match the symptom to the layer.
- **`for:` duration** prevents flapping — an alert must be true continuously for the window before firing. Scenarios about "alert fires on every transient blip" want a `for:` clause or better grouping.
- **Grouping, inhibition, silences** are distinct: grouping bundles related alerts, inhibition suppresses lower-severity ones when a higher fires, silences mute known/maintenance windows. Don't conflate them.

**Resources:**
- [Alertmanager overview](https://prometheus.io/docs/alerting/latest/alertmanager/) (~15 min)
- [Alerting/recording rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/) (~15 min)
- [Alertmanager configuration (routing/inhibition)](https://prometheus.io/docs/alerting/latest/configuration/) (~20 min)

## Summary
| Objective | Takeaway |
|---|---|
| `obs-metrics` | Prometheus pulls `/metrics`; ServiceMonitor/PodMonitor select targets; PromQL `rate()`/`sum by`; ≈ Azure Monitor Metrics |
| `obs-logs` | Loki indexes labels not content; LogQL filters + can make metrics from logs; ≈ Log Analytics/KQL |
| `obs-traces` | OTel Collector fans OTLP out; Tempo stores traces; traces answer "where in the call graph"; ≈ Application Insights |
| `obs-dashboards` | Grafana visualizes/correlates metrics→logs→traces; stores nothing; dashboards as JSON in Git; ≈ Azure Monitor Workbooks |
| `obs-alerting` | Prometheus/Grafana evaluate rules (`for:`), Alertmanager groups/inhibits/silences/routes; ≈ Azure Monitor alerts + action groups |
