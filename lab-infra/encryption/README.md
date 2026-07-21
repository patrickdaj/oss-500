# encryption — etcd secret encryption at rest

Turns Kubernetes Secrets from **base64 (not encrypted)** into **AES-CBC ciphertext
at rest in etcd**. Backs the encryption half of the lab
[d2-data-protection](../../labs/d2-data-protection.md).
**SC-500 correspondence:** Storage/SQL encryption at rest, customer-managed keys (CMK).

**Objectives:** `data-encrypt`

**Footprint:** no new pods — this reconfigures the existing kind control-plane
apiserver. Negligible resource cost; one apiserver restart.

By default a kind cluster stores Secrets in etcd with no encryption (the base is
kept plaintext on purpose so this lab shows the before/after — see
`lab-infra/kind/cluster.yaml`). This component supplies a real
`EncryptionConfiguration` and the exact steps to point kube-apiserver at it.

```bash
./up.sh          # generates a key, copies the config to the node, prints the
                 # apiserver manifest edits + the re-encrypt command
```

Because the change edits the kube-apiserver **static pod manifest inside the
control-plane container**, `up.sh` copies the config and prints the precise edits
rather than mutating a live control plane blindly.

**Verify (before/after — the money shot for `data-encrypt`)**
```bash
# Create a probe secret
kubectl -n oss500-apps create secret generic probe --from-literal=pw=SUPERSECRET

# Read it straight out of etcd on the node. BEFORE enabling encryption the value
# is plainly visible; AFTER (and after the re-encrypt) it reads k8s:enc:aescbc:...
docker exec oss500-control-plane sh -c \
 'ETCDCTL_API=3 etcdctl \
   --cacert /etc/kubernetes/pki/etcd/ca.crt \
   --cert   /etc/kubernetes/pki/etcd/server.crt \
   --key    /etc/kubernetes/pki/etcd/server.key \
   get /registry/secrets/oss500-apps/probe | hexdump -C | head'
```

**Teardown**
```bash
./down.sh        # prints the safe revert order; simplest reset is kind delete cluster
```

> Docs: https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/
> The real `encryption-config.yaml` (holds the KEK) is gitignored; only
> `encryption-config.yaml.example` is tracked.
