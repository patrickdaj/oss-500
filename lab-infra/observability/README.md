# lab-infra/observability — Prometheus, Grafana, Loki, Tempo, OpenTelemetry

The open-source observability triad for Domain 4 (`obs-*`): metrics (Prometheus), logs (Loki), traces (Tempo/OpenTelemetry), visualization (Grafana), alerting (Alertmanager). Deployed into the `oss500-monitoring` namespace on the kind cluster via Helm + manifests. Backs the [d4-observability](../../labs/d4-observability.md) lab.

**SC-500 correspondence:** Azure Monitor Metrics (Prometheus) · Log Analytics (Loki) · Application Insights (Tempo/OTel) · Azure Monitor Workbooks (Grafana) · Azure Monitor alerts + action groups (Alertmanager).

## ⚠ Heavy footprint — run alone

This is one of the two heaviest stacks in the course (the other is [`siem/`](../siem/)). It pulls Prometheus + Alertmanager + Grafana + Loki + Tempo + node/kube-state exporters + an OTel Collector. **Budget ~4–5 GB RAM and run it alone** — tear down `runtime/`, `ai/`, `supplychain/`, and the SIEM before `up.sh`. Do not run this and the SIEM the same day on the reference host.

## Layout

| File | Purpose | Objective |
|---|---|---|
| `up.sh` / `down.sh` | Helm install/uninstall + manifest apply/delete | `gov-iac` |
| `grafana-admin.env.example` | Grafana admin credential template (copy to `grafana-admin.env`, gitignored) | `obs-dashboards` |
| `prometheus-values.yaml` | kube-prometheus-stack Helm values (Prometheus, Alertmanager, Grafana, exporters) | `obs-metrics`, `obs-alerting` |
| `loki-values.yaml` | grafana/loki Helm values (single-binary, filesystem) | `obs-logs` |
| `tempo-values.yaml` | grafana/tempo Helm values (monolithic, OTLP receiver) | `obs-traces` |
| `otel-collector.yaml` | OpenTelemetry Collector Deployment (OTLP in → Tempo/Prometheus/Loki out) | `obs-traces` |
| `alert-rules.yaml` | `PrometheusRule` — `AuthFailureSpike` + crash-loop | `obs-alerting` |
| `alertmanager-config.yaml` | Alertmanager routing tree (grouping, inhibition, security receiver) | `obs-alerting` |
| `datasources.yaml` | Grafana data sources (Prometheus/Loki/Tempo, fixed uids) provisioned | `obs-dashboards` |
| `dashboards.yaml` | The provisioned four-panel **OSS-500 Posture** dashboard ConfigMap | `obs-dashboards` |
| `demo-authlog.yaml` | Demo app that logs SSH-style auth failures (log/alert target) | `obs-logs`, `obs-alerting` |
| `demo-traced-app.yaml` | OTel-instrumented frontend→backend (trace target) | `obs-traces` |

## Usage

```bash
kind create cluster --name oss500 --config ../kind/cluster.yaml   # if not already up
../shared/up.sh                                                   # namespaces + ingress
cp grafana-admin.env.example grafana-admin.env                   # set a strong admin password
./up.sh
# ...do labs/d4-observability.md, verify a fired alert reaches Alertmanager...
./down.sh
```

Grafana is exposed on the ingress at `http://localhost:8080` (Host header `grafana.localtest.me`) or via `kubectl -n oss500-monitoring port-forward svc/oss500-grafana 3000:80`.

## Secrets hygiene

`grafana-admin.env` is gitignored — only `grafana-admin.env.example` is committed. Never commit the real admin password. The stack uses `app.kubernetes.io/part-of: oss500` on everything for teardown:
`kubectl get all -n oss500-monitoring -l app.kubernetes.io/part-of=oss500`.

## Charts / images used

- `prometheus-community/kube-prometheus-stack` (Prometheus Operator, Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics)
- `grafana/loki` (single-binary) + `grafana/tempo` (monolithic)
- `otel/opentelemetry-collector-contrib`
