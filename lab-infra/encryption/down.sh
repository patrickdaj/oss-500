#!/usr/bin/env bash
# data-encrypt: revert etcd encryption on the kind control-plane.
# IMPORTANT ORDER: to safely turn encryption OFF you must first make `identity`
# (plaintext) the WRITER so Secrets get rewritten in the clear, re-encrypt, THEN
# remove the flag — otherwise the apiserver can't read them without the key.
set -euo pipefail
NODE=oss500-control-plane

cat <<'EOF'
==> To fully revert (optional — most labs just `kind delete cluster`):

  1. Edit encryption-config.yaml so `identity: {}` is the FIRST provider (the writer),
     copy it back, let the apiserver restart, then rewrite Secrets as plaintext:
        docker cp encryption-config.yaml oss500-control-plane:/etc/kubernetes/enc/encryption-config.yaml
        kubectl get secrets -A -o json | kubectl replace -f -

  2. Remove the --encryption-provider-config flag + enc volume/volumeMount from
     /etc/kubernetes/manifests/kube-apiserver.yaml on the node and let it restart.
EOF

echo "==> Removing the config file from the node (flag edit is manual, see above)"
docker exec "$NODE" rm -f /etc/kubernetes/enc/encryption-config.yaml || true
echo "==> Cleanest reset is always:  kind delete cluster --name oss500"
