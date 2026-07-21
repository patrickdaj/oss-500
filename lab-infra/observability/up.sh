#!/usr/bin/env bash
# Bring up the OSS-500 observability stack (obs-*): Prometheus + Alertmanager +
# Grafana + Loki + Tempo + OpenTelemetry Collector in oss500-monitoring.
# HEAVY: run this alone (see README). Requires the kind cluster + shared/up.sh done.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ns=oss500-monitoring

command -v helm >/dev/null || { echo "helm required"; exit 1; }
kubectl get ns "$ns" >/dev/null 2>&1 || { echo "Run ../shared/up.sh first (missing $ns)"; exit 1; }

# --- Grafana admin credential from the gitignored env file (obs-dashboards) ---
[ -f "$here/grafana-admin.env" ] || { echo "Copy grafana-admin.env.example -> grafana-admin.env and set a password"; exit 1; }
# shellcheck disable=SC1091
set -a; . "$here/grafana-admin.env"; set +a
echo "==> Creating grafana-admin secret"
kubectl create secret generic grafana-admin -n "$ns" \
  --from-literal=admin-user="${GRAFANA_ADMIN_USER}" \
  --from-literal=admin-password="${GRAFANA_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Adding Helm repos"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo update >/dev/null

echo "==> Installing kube-prometheus-stack (Prometheus, Alertmanager, Grafana, exporters)"
helm upgrade --install oss500-kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n "$ns" -f "$here/prometheus-values.yaml" --wait --timeout 10m

echo "==> Installing Loki (single-binary)"
helm upgrade --install oss500-loki grafana/loki -n "$ns" -f "$here/loki-values.yaml" --wait --timeout 10m

echo "==> Installing Tempo (monolithic, OTLP receiver)"
helm upgrade --install oss500-tempo grafana/tempo -n "$ns" -f "$here/tempo-values.yaml" --wait --timeout 10m

echo "==> Applying Grafana datasources, OTel Collector, alert rules, Alertmanager routing"
kubectl apply -f "$here/datasources.yaml"
kubectl apply -f "$here/otel-collector.yaml"
kubectl apply -f "$here/alert-rules.yaml"
kubectl apply -f "$here/alertmanager-config.yaml"

echo "==> Done. Grafana: http://grafana.localtest.me:8080  (or port-forward svc/oss500-grafana 3000:80)"
echo "    Verify: kubectl get pods -n $ns -l app.kubernetes.io/part-of=oss500"
