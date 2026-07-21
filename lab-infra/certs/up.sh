#!/usr/bin/env bash
# Bring up cert-manager and the OSS-500 CA ClusterIssuer.
# SC-500 correspondence: Azure Key Vault certificates + certificate lifecycle.
# Objectives: cert-issuer cert-lifecycle  (key-hsm is a walkthrough — see the lab)
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-secrets

echo "==> Adding the jetstack Helm repo"
helm repo add jetstack https://charts.jetstack.io >/dev/null
helm repo update >/dev/null

echo "==> Installing cert-manager into $NS  [cert-issuer]"
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace "$NS" \
  --set crds.enabled=true \
  -f "$here/values.yaml" \
  --wait --timeout 5m

echo "==> Waiting for the cert-manager controllers"
kubectl -n "$NS" rollout status deploy/cert-manager --timeout=180s
kubectl -n "$NS" rollout status deploy/cert-manager-webhook --timeout=180s
kubectl -n "$NS" rollout status deploy/cert-manager-cainjector --timeout=180s

echo "==> Creating the self-signed bootstrap issuer + CA + ca-issuer  [cert-issuer]"
kubectl apply -f "$here/clusterissuer.yaml"

echo "==> Waiting for the root CA certificate to be issued"
kubectl -n "$NS" wait --for=condition=Ready certificate/oss500-ca --timeout=120s

cat <<'EOF'

==> cert-manager is up. Issue the demo leaf cert (cert-lifecycle):

    kubectl apply -f example-certificate.yaml
    kubectl -n oss500-apps get certificate demo-tls -w      # Ready=True
    cmctl status certificate demo-tls -n oss500-apps        # renewal timing
EOF
