#!/usr/bin/env bash
# data-encrypt: turn on etcd Secret encryption at rest on the kind control-plane.
# This edits the kube-apiserver static pod manifest INSIDE the control-plane node
# container, so it is inherently hands-on/fiddly — up.sh copies the config and
# PRINTS the exact manifest edits + re-encrypt command rather than blindly sed'ing
# a live control plane.
# SC-500 correspondence: Storage/SQL encryption at rest with a (customer-managed) key.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE=oss500-control-plane

# data-encrypt: encryption-config.yaml holds the KEK that decrypts every Secret in
# etcd, so it is gitignored — seed it from the template on a clean clone.
if [ ! -f "$here/encryption-config.yaml" ]; then
  echo "==> Seeding encryption-config.yaml from the template"
  cp "$here/encryption-config.yaml.example" "$here/encryption-config.yaml"
fi
# Generate a fresh AES key if the file still holds the template/placeholder value.
if grep -qE "REPLACE_WITH_BASE64_32_BYTE_KEY|bGFiLW9ubHkta2V5" "$here/encryption-config.yaml" 2>/dev/null; then
  echo "==> Generating a fresh AES key into encryption-config.yaml"
  KEY="$(head -c 32 /dev/urandom | base64)"
  # portable in-place edit; only rewrites the writer key line
  sed "s#secret: REPLACE_WITH_BASE64_32_BYTE_KEY#secret: ${KEY}#; s#secret: bGFiLW9ubHkta2V5.*#secret: ${KEY}#" \
    "$here/encryption-config.yaml" > "$here/.enc.tmp" && mv "$here/.enc.tmp" "$here/encryption-config.yaml"
fi

echo "==> Copying EncryptionConfiguration into the control-plane node"
docker exec "$NODE" mkdir -p /etc/kubernetes/enc
docker cp "$here/encryption-config.yaml" "$NODE:/etc/kubernetes/enc/encryption-config.yaml"

cat <<'EOF'

==> Now wire the apiserver to it. Edit the static pod manifest ON THE NODE:

    docker exec -it oss500-control-plane vi /etc/kubernetes/manifests/kube-apiserver.yaml

  1. Add this flag to the kube-apiserver command:
       --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml
  2. Add a volumeMount to the kube-apiserver container:
       - name: enc
         mountPath: /etc/kubernetes/enc
         readOnly: true
  3. Add the matching hostPath volume:
       - name: enc
         hostPath:
           path: /etc/kubernetes/enc
           type: DirectoryOrCreate

  Saving the file makes the kubelet restart the apiserver automatically. Wait:
       kubectl -n kube-system get pod -l component=kube-apiserver -w

==> data-encrypt: re-encrypt EVERY existing Secret (they were written as plaintext
    before this change; rewriting them makes the apiserver encrypt them):

       kubectl get secrets -A -o json | kubectl replace -f -

==> Prove it (before/after) with:  ./verify-etcd.sh   (see README)
EOF
