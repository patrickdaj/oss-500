# Lab d2: Encrypt data at rest & scan for exposed secrets

Prove a Kubernetes Secret sits in etcd as readable plaintext, turn on encryption-at-rest and watch the same key become ciphertext, then hunt planted secrets in a repo and an image.

**Objectives covered**

| id | Objective |
|---|---|
| `data-encrypt` | Encrypt data at rest: etcd secrets, volumes, and application data |
| `data-secretscan` | Scan repositories and images for plaintext secrets |

**SC-500 correspondence**: Storage/SQL encryption at rest & customer-managed keys, CMK (etcd `EncryptionConfiguration`) · Defender CSPM secret scanning (Trivy / Gitleaks)

**Prerequisites**

- [`lab-infra/encryption`](../lab-infra/encryption/) up (`./up.sh`) — provides the `EncryptionConfiguration` and the kube-apiserver patch for the kind cluster.
- Notes read: [data-protection.md](../domains/2-secrets-data-networking/data-protection.md).
- `trivy` and `gitleaks` installed locally (the component README lists install commands), plus `docker`/`etcdctl` access to the kind node.

**Estimated time**: 2–2.5 h · $0 (local)

## Steps

### Part A — Encrypt Secrets at rest in etcd (`data-encrypt`)

By default kind/kubeadm store Secrets in etcd **unencrypted** (only base64-encoded). We'll prove it, then close the gap — the OSS equivalent of "storage/SQL encryption at rest," with the DEK provider standing in for a CMK.

1. **Create a Secret** whose value we'll go hunting for in etcd:
   ```bash
   kubectl -n oss500-apps create secret generic canary --from-literal=token=SUPERSECRET-PLAINTEXT-123
   ```
2. **Read it straight out of etcd — BEFORE.** etcd runs as a static pod on the kind control-plane node; exec in and dump the raw key:
   ```bash
   docker exec -it oss500-control-plane sh -c '
     ETCDCTL_API=3 etcdctl \
       --cacert /etc/kubernetes/pki/etcd/ca.crt \
       --cert   /etc/kubernetes/pki/etcd/server.crt \
       --key    /etc/kubernetes/pki/etcd/server.key \
       get /registry/secrets/oss500-apps/canary | strings'
   # ...you can READ  SUPERSECRET-PLAINTEXT-123  right there in etcd. Base64 != encryption.
   ```
   This is the whole point of the fundamentals warning: a `Secret` is not encrypted at rest by default. Anyone with etcd/node access — or an etcd backup — reads it.
3. **Apply the EncryptionConfiguration.** The `encryption/` component drops `encryption-config.yaml` on the node and patches the apiserver to load it. Provider order matters — the *first* provider encrypts new writes:
   ```yaml
   # lab-infra/encryption/encryption-config.yaml (reference)
   apiVersion: apiserver.config.k8s.io/v1
   kind: EncryptionConfiguration
   resources:
     - resources: ["secrets"]                 # data-encrypt: encrypt Secret objects at rest
       providers:
         - aescbc:                             # AES-CBC with a locally-held key (stand-in for a CMK/KMS DEK)
             keys:
               - name: key1
                 secret: <base64-32-byte-key> # from encryption/keygen.sh -> encryption-config.secret.example
         - identity: {}                        # fallback for reads of not-yet-encrypted data
   ```
   > Production hardening: replace the local `aescbc` key with a **KMS provider** backed by Vault transit / an HSM — the true CMK model, where the apiserver calls out to Vault to wrap the data-encryption key. That's `key-transit` (see [d2-cert-manager](d2-cert-manager.md) Part A) wired into the KMS plugin.
   ```bash
   cd lab-infra/encryption && ./up.sh          # installs config + restarts kube-apiserver with --encryption-provider-config
   ```
4. **Re-encrypt existing Secrets.** The config only encrypts *future* writes; force-rewrite everything so the old plaintext `canary` gets encrypted:
   ```bash
   kubectl get secrets --all-namespaces -o json | kubectl replace -f -
   ```
5. **Read it out of etcd again — AFTER.** Same key, now ciphertext:
   ```bash
   docker exec -it oss500-control-plane sh -c '
     ETCDCTL_API=3 etcdctl \
       --cacert /etc/kubernetes/pki/etcd/ca.crt \
       --cert   /etc/kubernetes/pki/etcd/server.crt \
       --key    /etc/kubernetes/pki/etcd/server.key \
       get /registry/secrets/oss500-apps/canary | strings'
   # now begins with  k8s:enc:aescbc:v1:key1:  followed by ciphertext -- the plaintext is gone.
   ```
6. Confirm the app path still works transparently (the apiserver decrypts on read):
   ```bash
   kubectl -n oss500-apps get secret canary -o jsonpath='{.data.token}' | base64 -d    # SUPERSECRET-PLAINTEXT-123
   ```
   Same secret, same API — but at rest it is now `k8s:enc:aescbc:...`. (Volumes: encrypt PV-backed data with LUKS/`StorageClass` encryption; application data: Vault transit from the cert lab.)

### Part B — Scan repos & images for plaintext secrets (`data-secretscan`)

Encryption protects secrets *that live in the vault/etcd*; secret scanning catches the ones that **escaped** into code and images — the Defender CSPM secret-scanning analogue.

7. **Plant** a couple of secrets to find (in the scratchpad, not a real repo):
   ```bash
   mkdir -p /tmp/secretscan-demo && cd /tmp/secretscan-demo && git init -q
   cat > app.py <<'EOF'
   AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
   AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
   EOF
   git add app.py && git commit -qm "add app"      # secret is now in history, not just the worktree
   ```
8. **Trivy — filesystem secret scan:**
   ```bash
   trivy fs --scanners secret /tmp/secretscan-demo
   # HIGH  AWS Access Key ID  app.py:1  ...
   ```
9. **Trivy — image secret scan** (bake a secret into an image, then scan the layers):
   ```bash
   printf 'FROM alpine:3.20\nENV DB_PASSWORD=hunter2-prod\nRUN echo "AKIAIOSFODNN7EXAMPLE" > /root/.aws_key\n' > Dockerfile
   docker build -t leaky:demo .
   trivy image --scanners secret leaky:demo
   # detects the AWS key in the layer / the ENV secret
   ```
10. **Gitleaks — scan git history** (catches secrets even after they're deleted from HEAD):
    ```bash
    gitleaks detect --source /tmp/secretscan-demo --verbose --report-format json --report-path /tmp/gitleaks.json
    # Finding: AWS ... commit <sha> app.py  -> nonzero exit code (fails CI)
    ```
11. **Shift left — pre-commit hook** so secrets never get committed in the first place:
    ```bash
    # .pre-commit-config.yaml
    repos:
      - repo: https://github.com/gitleaks/gitleaks
        rev: v8.18.4
        hooks: [{ id: gitleaks }]
    ```
    ```bash
    pre-commit install    # now `git commit` runs gitleaks and blocks the commit if it finds a secret
    ```
    Remediation the exam wants (same as Defender): **move the secret into the vault + rotate the exposed credential + prefer workload identity** so there's no static secret at all — exactly [d2-vault-k8s-injection](d2-vault-k8s-injection.md).

## Verification

- **Encryption at rest**: the *same* etcd key `/registry/secrets/oss500-apps/canary` shows readable plaintext (`SUPERSECRET-PLAINTEXT-123`) **before** the EncryptionConfiguration and shows the `k8s:enc:aescbc:v1:key1:` ciphertext prefix **after** — while `kubectl get secret` still returns the value transparently.
- **Secret scanning**: `trivy fs --scanners secret` and `gitleaks detect` each emit a finding for the planted AWS key (Gitleaks flags it in git *history*, not just the worktree), and `trivy image` finds the secret baked into `leaky:demo`. The Gitleaks pre-commit hook blocks a new commit containing a secret.

## Teardown

- `cd lab-infra/encryption && ./down.sh`
- `rm -rf /tmp/secretscan-demo && docker rmi leaky:demo`

## What the exam asks

- A Kubernetes `Secret` is **base64, not encrypted, at rest by default** — the fix is an `EncryptionConfiguration` on the apiserver (etcd encryption), the analogue of storage/SQL encryption at rest. Enabling it only encrypts **future** writes; existing objects need a `kubectl get ... | kubectl replace -f -` rewrite.
- The **provider order** matters: the first provider encrypts new writes; `identity` must stay available (usually last) to read older data. A KMS provider (→ Vault/HSM) is the **customer-managed key (CMK)** model, versus a locally-held `aescbc` key.
- **Encryption vs secret scanning** solve different problems: encryption protects data *inside* the store; scanning finds secrets that **leaked outside** it (code, images, disks). CMK/at-rest questions ≠ secret-sprawl questions.
- **Gitleaks scans git history**, so a secret is exposed the moment it is committed *even if later removed* — the remediation is always **rotate the credential**, not just delete the line. Shift-left with a pre-commit hook + a CI scan (Trivy/Gitleaks) is the preventive control.
- Trivy does double duty: vulnerability *and* secret scanning of both filesystems and images (`--scanners secret`).
