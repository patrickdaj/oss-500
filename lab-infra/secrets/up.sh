#!/usr/bin/env bash
# Bring up HashiCorp Vault (dev mode) + Agent Injector + Secrets Store CSI driver.
# SC-500 correspondence: Azure Key Vault (secrets/keys/certs manager).
# Objectives: vault-deploy vault-access vault-dynamic vault-rotation vault-k8s
#             vault-audit key-transit
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-secrets

echo "==> Adding Helm repos"
helm repo add hashicorp https://helm.releases.hashicorp.com >/dev/null
helm repo add secrets-store-csi-driver \
  https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts >/dev/null
helm repo update >/dev/null

echo "==> Installing Vault (dev mode) into $NS  [vault-deploy]"
# vault-deploy: dev mode auto-inits + auto-unseals with root token "root".
# Real deploys use HA Raft + auto-unseal (see values.yaml, commented).
helm upgrade --install vault hashicorp/vault \
  --namespace "$NS" \
  -f "$here/values.yaml" \
  --wait --timeout 5m

echo "==> Installing Secrets Store CSI driver  [vault-k8s]"
# vault-k8s: the CSI driver + Vault provider is the alternative to the injector.
helm upgrade --install csi secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace "$NS" \
  --set syncSecret.enabled=true \
  --set enableSecretRotation=true \
  --wait --timeout 5m

echo "==> Waiting for Vault to be ready"
kubectl -n "$NS" wait --for=condition=ready pod/vault-0 --timeout=180s

echo "==> Labelling workloads for teardown discovery"
kubectl -n "$NS" label pod vault-0 app.kubernetes.io/part-of=oss500 --overwrite >/dev/null || true

cat <<'EOF'

==> Vault is up (dev mode). Configure the engines the labs use:

    ./configure.sh          # audit device, kubernetes auth, transit, database engine

    # Root-token shell (dev root token is "root"):
    kubectl -n oss500-secrets exec -it vault-0 -- sh
    export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root
    vault status

    # UI:  kubectl -n oss500-secrets port-forward svc/vault 8200:8200
EOF
