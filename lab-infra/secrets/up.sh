#!/usr/bin/env bash
# Bring up HashiCorp Vault (single-node Raft) + Agent Injector + Secrets Store
# CSI driver + a Postgres backend for the dynamic-secrets lab.
# SC-500 correspondence: Azure Key Vault (secrets/keys/certs manager).
# Objectives: vault-deploy vault-access vault-dynamic vault-rotation vault-k8s
#             vault-audit key-transit
#
# Unlike dev mode, Raft boots SEALED: this script initialises Vault and unseals
# it, writing the Shamir unseal keys + root token to the gitignored
# .vault-init.json (the file the lab logs in from). Secrets persist across
# restarts; a restart re-seals, and you re-run the unseal loop below.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-secrets
INIT_FILE="$here/.vault-init.json"

command -v jq >/dev/null || { echo "jq required (brew install jq / apt-get install jq)"; exit 1; }

echo "==> Adding Helm repos"
helm repo add hashicorp https://helm.releases.hashicorp.com >/dev/null
helm repo add secrets-store-csi-driver \
  https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts >/dev/null
helm repo update >/dev/null

echo "==> Installing Vault (single-node Raft) into $NS  [vault-deploy]"
# No --wait: a Raft server boots SEALED and won't report Ready until unsealed.
helm upgrade --install vault hashicorp/vault \
  --namespace "$NS" \
  -f "$here/values.yaml"

echo "==> Waiting for the vault-0 pod to start (it will be Running but SEALED)"
for _ in $(seq 1 60); do
  [ "$(kubectl -n "$NS" get pod vault-0 -o jsonpath='{.status.phase}' 2>/dev/null || true)" = "Running" ] && break
  sleep 3
done

# Let the API come up on 127.0.0.1:8200 inside the pod (status exits non-zero
# while sealed/uninitialised — we only need the endpoint to answer).
for _ in $(seq 1 30); do
  kubectl -n "$NS" exec vault-0 -- sh -c 'vault status >/dev/null 2>&1; [ $? -ne 1 ]' && break
  sleep 3
done

vstat() { kubectl -n "$NS" exec vault-0 -- vault status -format=json 2>/dev/null; }

if [ "$(vstat | jq -r '.initialized // false')" != "true" ]; then
  echo "==> Initialising Vault  [vault-deploy] — writing $INIT_FILE (gitignored)"
  kubectl -n "$NS" exec vault-0 -- vault operator init \
    -key-shares=3 -key-threshold=3 -format=json > "$INIT_FILE"
  chmod 600 "$INIT_FILE"
else
  echo "==> Vault already initialised; using existing $INIT_FILE"
  [ -f "$INIT_FILE" ] || { echo "ERROR: Vault is initialised but $INIT_FILE is missing — cannot unseal."; exit 1; }
fi

if [ "$(vstat | jq -r '.sealed // true')" = "true" ]; then
  echo "==> Unsealing Vault with 3 of 3 Shamir shares  [vault-deploy]"
  for i in 0 1 2; do
    kubectl -n "$NS" exec vault-0 -- vault operator unseal \
      "$(jq -r ".unseal_keys_b64[$i]" "$INIT_FILE")" >/dev/null
  done
fi

echo "==> Waiting for Vault to report Ready (unsealed)"
kubectl -n "$NS" wait --for=condition=ready pod/vault-0 --timeout=120s
kubectl -n "$NS" label pod vault-0 app.kubernetes.io/part-of=oss500 --overwrite >/dev/null || true

echo "==> Installing Secrets Store CSI driver  [vault-k8s]"
helm upgrade --install csi secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace "$NS" \
  --set syncSecret.enabled=true \
  --set enableSecretRotation=true \
  --wait --timeout 5m

echo "==> Deploying the Postgres backend for dynamic secrets  [vault-dynamic]"
kubectl apply -f "$here/postgres.yaml"
kubectl -n "$NS" rollout status deploy/postgres --timeout=120s
kubectl -n "$NS" rollout status deploy/psql-client --timeout=120s

ROOT_TOKEN="$(jq -r '.root_token' "$INIT_FILE")"
cat <<EOF

==> Vault is up (Raft, unsealed). Configure the engines the labs use:

    ./configure.sh          # audit device, kubernetes auth, transit, database engine

    # Root-token shell (root token + unseal keys are in .vault-init.json):
    kubectl -n $NS exec -it statefulset/vault -- sh
    export VAULT_ADDR=http://127.0.0.1:8200
    vault login $ROOT_TOKEN
    vault status            # Storage Type raft, Sealed false

    # Postgres backend for dynamic secrets is up at postgres.$NS:5432 (db appdb).
    # UI:  kubectl -n $NS port-forward svc/vault 8200:8200
EOF
