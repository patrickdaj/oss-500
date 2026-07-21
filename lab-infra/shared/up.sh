#!/usr/bin/env bash
# Shared cluster bootstrap: namespaces + ingress-nginx (net-ingress).
# Run once after `kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml`.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Applying OSS-500 namespaces + Pod Security labels"
kubectl apply -f "$here/namespaces.yaml"

echo "==> Installing ingress-nginx (kind flavour) — ingress on localhost:8080/8443"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "==> Waiting for ingress-nginx to be ready"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo "==> Done. Verify:  kubectl get all -A -l app.kubernetes.io/part-of=oss500"
