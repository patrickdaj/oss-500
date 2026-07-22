# Collect metrics, logs, and traces for security monitoring

Domain 4, subsection 1 (`d4-observability`). Security monitoring starts with telemetry: you cannot detect, alert on, or investigate what you never collected. This subsection builds the open-source observability triad — **metrics** (Prometheus), **logs** (Loki), and **traces** (Tempo/OpenTelemetry) — visualized in **Grafana** and made actionable by **Alertmanager**. It is the OSS analogue of the Azure Monitor family: Azure Monitor Metrics, Log Analytics, Application Insights, Workbooks, and Azure Monitor alerts. Primary lab: [d4-observability](../../labs/d4-observability.md) on the [`lab-infra/observability`](../../lab-infra/observability/) stack (kube-prometheus-stack + Loki + Tempo + an OpenTelemetry Collector).

## Collect and query metrics

*Objective: `obs-metrics` · OSS: Prometheus ≈ SC-500: Azure Monitor · Lab: [d4-observability](../../labs/d4-observability.md)*

Prometheus is a **pull-based** time-series database: a scrape loop hits each target's `/metrics` HTTP endpoint on an interval and stores the samples, each identified by a metric name plus a set of key/value **labels** (`http_requests_total{code="500",job="api"}`). In Kubernetes the Prometheus Operator (shipped by the `kube-prometheus-stack` Helm chart) turns scrape config into custom resources — `ServiceMonitor` and `PodMonitor` select targets by label, so you never hand-edit `prometheus.yml`. Node and cluster security signals arrive out of the box: `node-exporter` (host CPU/mem/disk/filesystem), `kube-state-metrics` (object state — e.g. a pod running as privileged), and cAdvisor (per-container usage).

You wire a target in with a `ServiceMonitor` — the operator reads the CR and rewrites `prometheus.yml` for you:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata: { name: api, labels: { release: kube-prometheus-stack } }
spec:
  selector: { matchLabels: { app: api } }   # selects the Service
  endpoints:
    - port: metrics                          # named port on the Service
      interval: 30s
      path: /metrics
```

The `labels.release` must match the operator's `serviceMonitorSelector` or the CR is silently ignored — the single most common "my target never appears in Status → Targets" failure.

You query with **PromQL**. Security-relevant examples: `rate(apiserver_request_total{code=~"5.."}[5m])` for API-server error spikes, `kube_pod_container_status_restarts_total` climbing on a workload (possible crash-loop from a killed exploit), or `count(kube_pod_info) by (namespace)` to spot unexpected pod sprawl. A privilege-drift alert: `count(kube_pod_container_status_running) by (namespace) unless kube_pod_container_status_running` — or more usefully `sum(kube_pod_spec_containers_security_context_privileged) > 0` to catch any privileged container. PromQL's `rate()` vs `irate()` (use `rate()` for alerting — it's smoothed over the window), `increase()`, aggregation operators (`sum by`, `count by`), and label matchers (`=`, `!=`, `=~`, `!~`) are the core you must read fluently. A classic pitfall: `rate()` on a gauge (not a counter) is meaningless — `rate()` only makes sense on monotonically-increasing counters.

The SC-500 mapping: Prometheus ≈ **Azure Monitor Metrics**, `ServiceMonitor`/`PodMonitor` ≈ the Azure Monitor managed Prometheus scrape config / DCRs, and PromQL ≈ the metrics query experience. Azure Monitor managed Prometheus is literally Prometheus-compatible — Microsoft ships a managed Prometheus that ingests the same exposition format and queries with PromQL — so this is one of the tightest OSS↔Azure equivalences in the whole curriculum.

Exam gotchas:
- Prometheus **pulls**; it does not receive pushes (the Pushgateway is only for short-lived batch jobs, and is an anti-pattern for service metrics). "Configure the app to push metrics to Prometheus" is wrong.
- Prometheus is for metrics (numeric time series), **not** logs. High-cardinality data (user IDs, request IDs, full URLs) as labels will blow up memory — every unique label-value combination is a new time series — that belongs in Loki, not a Prometheus label.
- Local Prometheus storage is not long-term/HA; Thanos or Mimir (or Azure Monitor managed Prometheus) handle durable, multi-cluster retention. Recognize them as the "long-term metrics" answer.
- `rate()` needs a **counter** and at least two samples in the window; on a **gauge** use raw value / `delta()` / `deriv()`. Mixing them up is a frequent PromQL trap.
- The operator only picks up a `ServiceMonitor` whose labels match its `serviceMonitorSelector` — a target "not scraping" is usually a label-selector mismatch, not a network problem.

**Resources:**
- [Prometheus overview](https://prometheus.io/docs/introduction/overview/) (~15 min)
- [Querying basics (PromQL)](https://prometheus.io/docs/prometheus/latest/querying/basics/) (~20 min)
- [PromQL operators & aggregation](https://prometheus.io/docs/prometheus/latest/querying/operators/) (~15 min)
- [Prometheus Operator ServiceMonitor design](https://prometheus-operator.dev/docs/getting-started/design/#servicemonitor) (~15 min)
- [Azure Monitor managed Prometheus overview](https://learn.microsoft.com/en-us/azure/azure-monitor/metrics/prometheus-metrics-overview) (~15 min)

## Aggregate and query logs

*Objective: `obs-logs` · OSS: Loki ≈ SC-500: Log Analytics · Lab: [d4-observability](../../labs/d4-observability.md)*

Grafana **Loki** is a log-aggregation system deliberately modeled on Prometheus: it indexes only a small set of **labels** per stream (namespace, pod, container, app) and stores the raw log lines compressed in object storage, rather than full-text indexing every field like Elasticsearch/OpenSearch. That makes it cheap to run but shifts filtering into query time. A collector — **Promtail**, Grafana **Alloy**, or an OpenTelemetry Collector — tails pod stdout/stderr and ships lines to Loki with Kubernetes metadata attached as labels.

You query with **LogQL**. A LogQL query is a label selector (the "stream selector") followed by optional line/label filters and, optionally, a metric aggregation. The two-stage structure — cheap label match first, then line filter — is the performance model: `{namespace="oss500-apps"}` narrows to a handful of streams over object storage, and only then does `|=` scan lines. Examples:

```logql
# SSH brute-force lines, parsed
{namespace="oss500-apps", app="sshd"} |= "Failed password" | regexp `from (?P<src>\d+\.\d+\.\d+\.\d+)`
# Alertable rate of authz denials by pod
sum(rate({namespace="oss500-security"} |= "denied" [5m])) by (pod)
# Top offenders over the last hour (metric from logs)
topk(10, sum by (src) (count_over_time({app="sshd"} |= "Failed password" | regexp `from (?P<src>\S+)` [1h])))
```

That last form — LogQL over logs producing a time series — is how you build **log-based alerts** without a separate SIEM. Filter operators to know: `|=` (contains), `!=`, `|~` (regex), `!~`, and parser stages `| json`, `| logfmt`, `| regexp`, `| pattern`. A subtle failure mode: adding a parsed field as a **label** in a query (`| label_format`) or, worse, at ingest, re-introduces the exact cardinality explosion Loki was designed to avoid.

SC-500 mapping: Loki ≈ **Azure Monitor Logs / Log Analytics workspace**, the collector ≈ the Azure Monitor Agent + Data Collection Rules, and LogQL ≈ **KQL** (though KQL is far richer — Loki is filter-and-aggregate, KQL is a full analytics language). Both centralize logs so detections and hunts run against one store; in this course the heavier full-text hunting store is OpenSearch under the SIEM (`siem-hunt`), while Loki is the lightweight operational-log tier.

Exam gotchas:
- Loki indexes **labels, not content** — over-labeling (e.g. a label per request ID) creates high cardinality and kills performance, the same failure mode as Prometheus labels.
- Loki ≠ Elasticsearch: no per-field inverted index, so "full-text search across everything instantly" is an OpenSearch/Elastic strength, not Loki's. Know when a scenario wants Loki (cheap, label-scoped) vs OpenSearch (rich hunting).
- LogQL can produce metrics from logs (`rate`, `count_over_time`, `bytes_over_time`) — useful when you have no metric for an event but do have the log line.
- Parsing happens at **query time** by default (`| json`, `| logfmt`), not ingest — so you don't need to define a schema up front, but a heavy parse over a wide time range is slow. Narrow by label and time first.
- Promtail is being superseded by **Grafana Alloy** (the OTel-collector-based agent); recognize both as the shipper, distinct from Loki the store.

**Resources:**
- [Loki fundamentals & architecture](https://grafana.com/docs/loki/latest/get-started/architecture/) (~15 min)
- [LogQL log query language](https://grafana.com/docs/loki/latest/query/) (~20 min)
- [LogQL metric queries (rate/count_over_time)](https://grafana.com/docs/loki/latest/query/metric_queries/) (~15 min)
- [Loki labels — best practices & cardinality](https://grafana.com/docs/loki/latest/get-started/labels/) (~15 min)
- [Grafana Alloy (collector) overview](https://grafana.com/docs/alloy/latest/introduction/) (~10 min)

## Capture distributed traces

*Objective: `obs-traces` · OSS: Tempo / OpenTelemetry ≈ SC-500: Application Insights · Lab: [d4-observability](../../labs/d4-observability.md)*

A **distributed trace** follows one request across services: a root **span** (the incoming request) with child spans for each downstream call, all sharing a **trace ID** propagated in headers (W3C `traceparent`). This is how you answer "which of the eight services made this request slow" — and, for security, how you attribute a suspicious call chain, follow lateral movement between microservices, or tie an anomalous auth event to the exact downstream data access it triggered. Grafana **Tempo** is the trace backend; it indexes by trace ID and (with TraceQL) span attributes, storing spans cheaply in object storage.

**OpenTelemetry (OTel)** is the vendor-neutral instrumentation standard — SDKs plus the **OpenTelemetry Collector**, a pipeline of receivers → processors → exporters. Apps emit OTLP (the OpenTelemetry protocol) to the Collector, which batches/enriches and fans out: traces to Tempo, metrics to Prometheus, logs to Loki. A minimal Collector config makes the receivers→processors→exporters shape concrete:

```yaml
receivers:  { otlp: { protocols: { grpc: {}, http: {} } } }
processors: { batch: {}, tail_sampling: { policies: [{ name: errors, type: status_code, status_code: { status_codes: [ERROR] } }] } }
exporters:  { otlp/tempo: { endpoint: tempo:4317, tls: { insecure: true } } }
service:
  pipelines:
    traces: { receivers: [otlp], processors: [tail_sampling, batch], exporters: [otlp/tempo] }
```

OTel is the single most important convergence point in modern observability — one instrumentation, many backends — and it is exactly what the AI-security objective `ai-observability` reuses to audit LLM calls. Trace context propagates via the W3C `traceparent` header (`00-<trace-id>-<span-id>-01`); a broken chain (spans landing under different trace IDs) almost always means a hop dropped or failed to forward that header.

SC-500 mapping: Tempo + OTel ≈ **Application Insights** (distributed tracing, the application map), OTLP ≈ the Application Insights/Azure Monitor OpenTelemetry Distro (Azure Monitor natively ingests OTLP now), and TraceQL ≈ transaction search / the end-to-end transaction view. Microsoft's recommended path into Application Insights is the OpenTelemetry Distro, so the instrumentation skill transfers directly.

Exam gotchas:
- Traces answer **"where in the call graph,"** metrics answer **"how much/how often,"** logs answer **"what exactly happened."** A scenario asking to pinpoint which service in a chain introduced latency or an unexpected call → traces, not metrics.
- The **Collector** is a deploy-once fan-out point; you do not need a separate agent per backend. "Send OTLP to the Collector, it routes to Tempo/Prometheus/Loki" is the modern pattern.
- **Sampling**: head vs tail sampling controls trace volume/cost. **Head** sampling decides at the root before the trace completes (cheap, but can drop an error you didn't know was coming); **tail** sampling buffers the whole trace then decides (keep the interesting/erroring traces) — the answer when "keep failed traces but drop the noise."
- Trace context rides the **W3C `traceparent` header**; a service that doesn't propagate it breaks the trace into disconnected fragments. Instrumentation gaps, not the backend, are the usual cause of "half the trace is missing."
- OTel is **vendor-neutral** — the same instrumentation exports to Tempo, Jaeger, or Application Insights by swapping an exporter, which is the whole point of "instrument once."

**Resources:**
- [OpenTelemetry — what is OpenTelemetry](https://opentelemetry.io/docs/what-is-opentelemetry/) (~15 min)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) (~15 min)
- [OpenTelemetry sampling (head vs tail)](https://opentelemetry.io/docs/concepts/sampling/) (~15 min)
- [Grafana Tempo introduction](https://grafana.com/docs/tempo/latest/introduction/) (~15 min)
- [Enable Azure Monitor OpenTelemetry (App Insights)](https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-enable) (~15 min)

## Build monitoring dashboards

*Objective: `obs-dashboards` · OSS: Grafana ≈ SC-500: Azure Monitor Workbooks · Lab: [d4-observability](../../labs/d4-observability.md)*

**Grafana** is the visualization and correlation layer over every backend above: add Prometheus, Loki, and Tempo as **data sources**, then build **dashboards** of panels (time series, stat, table, logs, heatmap) each backed by a PromQL/LogQL/TraceQL query. For a security SOC you build a posture dashboard: API-server 5xx rate, pods running as root (from `kube-state-metrics`), denied-request logs from Loki, and a drill-down from a metric spike straight into the correlated log lines and the trace — the **metrics→logs→traces** correlation that makes an investigation fast. Dashboards are JSON and should live in Git (provisioned via ConfigMap/sidecar), which is itself the `gov-iac` discipline applied to monitoring.

The killer feature for incident response is cross-signal linking: a Grafana **exemplar** or a data-source-linked panel jumps from a latency spike (metric) to the exact trace ID (Tempo) and the pod's logs (Loki) at that timestamp — one pane, three signals. That is what "single pane of glass" actually means operationally. **Template variables** (`$namespace`, `$pod`) turn one dashboard into a reusable, scoped view — a query like `label_values(kube_pod_info, namespace)` populates a dropdown so the SOC pivots the whole board to one namespace during an incident.

Dashboards should be **provisioned** from Git rather than clicked together. A provider config points Grafana at a directory of dashboard JSON mounted via ConfigMap/sidecar:

```yaml
# /etc/grafana/provisioning/dashboards/security.yaml
apiVersion: 1
providers:
  - name: security
    folder: Security
    type: file
    options: { path: /var/lib/grafana/dashboards }
```

SC-500 mapping: Grafana dashboards ≈ **Azure Monitor Workbooks** (and Azure Managed Grafana is a first-party Azure service — Microsoft literally offers hosted Grafana), Grafana data sources ≈ Workbook data sources across Metrics/Logs/Resource Graph, and Grafana alerting overlaps Azure Monitor alerts. Provisioned dashboard JSON ≈ Workbook ARM templates.

Exam gotchas:
- Grafana is **visualization/query**, not storage — it holds no metrics or logs itself; killing Grafana loses no data. "Grafana went down, did we lose logs?" → no, the data is in Loki/Prometheus.
- Dashboards belong in source control (JSON, provisioned), not click-configured and forgotten — the IaC theme. A dashboard edited in the UI but never exported is lost on pod restart if provisioning is read-only.
- Grafana **datasource permissions and org/folder RBAC** matter: a read-only viewer role vs an editor is an access-control question, and Grafana can front-authenticate via OIDC (Keycloak from `d1`).
- **Template/dashboard variables** scope a shared dashboard to a namespace/pod/env; recognize them as the reuse mechanism, distinct from data sources (the backend connections).

**Resources:**
- [Grafana — introduction / what it is](https://grafana.com/docs/grafana/latest/introduction/) (~10 min)
- [Grafana dashboards — build your first](https://grafana.com/docs/grafana/latest/getting-started/build-first-dashboard/) (~20 min)
- [Grafana provisioning (dashboards/datasources as code)](https://grafana.com/docs/grafana/latest/administration/provisioning/) (~15 min)
- [Grafana data source management](https://grafana.com/docs/grafana/latest/administration/data-source-management/) (~10 min)

## Define alerting rules and routing

*Objective: `obs-alerting` · OSS: Alertmanager ≈ SC-500: Azure Monitor alerts · Lab: [d4-observability](../../labs/d4-observability.md)*

An alert has two halves. **Rule evaluation** lives in Prometheus (or Grafana): a PromQL expression that, when true for a `for:` duration, produces a firing alert with labels and annotations:

```yaml
groups:
  - name: security.rules
    rules:
      - alert: PrivilegedContainerRunning
        expr: sum(kube_pod_container_status_running * on(namespace,pod) group_left kube_pod_spec_containers_security_context_privileged) > 0
        for: 5m
        labels:    { severity: critical, team: security }
        annotations: { summary: "Privileged container in {{ $labels.namespace }}" }
```

**Routing** lives in **Alertmanager**: it deduplicates, groups (by cluster/namespace/alertname so one incident isn't 50 pages), applies **inhibition** (suppress the warning when the critical for the same target is already firing), respects **silences** (planned maintenance), and dispatches to receivers (email, Slack, PagerDuty, generic webhook) chosen by a routing tree that matches on alert labels — e.g. `severity: critical` → PagerDuty, `team: security` → the SOC channel:

```yaml
route:
  group_by: [alertname, namespace]
  receiver: default
  routes:
    - matchers: [ severity="critical" ]
      receiver: pagerduty
    - matchers: [ team="security" ]
      receiver: soc-slack
```

The security lens: alerting turns raw telemetry into an actioned signal. A default-deny NetworkPolicy violation logged in Loki, a Falco alert rate from `d3`, or an API-server error spike all become a routed, deduplicated, escalatable page. The rule/route split is the exam-critical concept — the *condition* and the *delivery* are separate systems, tuned separately.

SC-500 mapping: Prometheus/Grafana rules ≈ **Azure Monitor alert rules** (metric, log, and activity-log alerts), and Alertmanager ≈ **action groups + alert processing rules** (grouping, suppression during maintenance, routing to email/SMS/webhook/Logic App). Alertmanager silences ≈ alert processing rules that suppress during a maintenance window; inhibition ≈ suppressing dependent alerts.

Exam gotchas:
- **Rule (condition) vs route (delivery) are separate**: "the alert fires but nobody is paged" → the rule is fine, the Alertmanager route/receiver is misconfigured. Match the symptom to the layer.
- **`for:` duration** prevents flapping — an alert must be true continuously for the window before firing. Scenarios about "alert fires on every transient blip" want a `for:` clause or better grouping.
- **Grouping, inhibition, silences** are distinct: grouping bundles related alerts, inhibition suppresses lower-severity ones when a higher fires, silences mute known/maintenance windows. Don't conflate them.
- **Recording rules ≠ alerting rules**: recording rules precompute expensive expressions into new series (for speed/reuse); alerting rules evaluate a condition and fire. A "slow dashboard/alert query" answer is often a recording rule.
- Prefer **symptom-based, SLO-driven** alerts (user-visible impact) over cause-based noise — alert on the error-rate the user feels, not every underlying blip. This is the Google SRE alerting philosophy the exam echoes.

**Resources:**
- [Alertmanager overview](https://prometheus.io/docs/alerting/latest/alertmanager/) (~15 min)
- [Alerting/recording rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/) (~15 min)
- [Alertmanager configuration (routing/inhibition)](https://prometheus.io/docs/alerting/latest/configuration/) (~20 min)
- [Prometheus alerting best practices](https://prometheus.io/docs/practices/alerting/) (~10 min)
- [Google SRE Workbook — alerting on SLOs](https://sre.google/workbook/alerting-on-slos/) (~25 min)

## Summary
| Objective | Takeaway |
|---|---|
| `obs-metrics` | Prometheus pulls `/metrics`; ServiceMonitor/PodMonitor select targets; PromQL `rate()`/`sum by`; ≈ Azure Monitor Metrics |
| `obs-logs` | Loki indexes labels not content; LogQL filters + can make metrics from logs; ≈ Log Analytics/KQL |
| `obs-traces` | OTel Collector fans OTLP out; Tempo stores traces; traces answer "where in the call graph"; ≈ Application Insights |
| `obs-dashboards` | Grafana visualizes/correlates metrics→logs→traces; stores nothing; dashboards as JSON in Git; ≈ Azure Monitor Workbooks |
| `obs-alerting` | Prometheus/Grafana evaluate rules (`for:`), Alertmanager groups/inhibits/silences/routes; ≈ Azure Monitor alerts + action groups |
