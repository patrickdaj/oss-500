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

## Challenge

This is a **guided build**. You write the `EncryptionConfiguration`, hand-wire the apiserver to it, and drive the scanners yourself; check against the Reference solution after.

**Part A — `data-encrypt`.** Prove a Kubernetes `Secret` sits in etcd as **base64, not ciphertext**, by default. Then turn on etcd encryption-at-rest and prove the *same* Secret's on-disk representation flips to ciphertext — while `kubectl get secret` keeps decrypting it transparently. **Observable**: the value at etcd key `/registry/secrets/oss500-apps/canary` reads as plain `SUPERSECRET-PLAINTEXT-123` before you touch anything, and reads with a `k8s:enc:aescbc:v1:key1:` ciphertext prefix after you enable encryption and re-encrypt existing Secrets.

**Part B — `data-secretscan`.** Plant a realistic AWS key in a git repo (so it lands in history) and bake one into a Docker image, then catch both with two different open-source scanners and stop the next one from ever being committed. **Observable**: `trivy fs --scanners secret` and `gitleaks detect` each emit a finding for the planted AWS key — Gitleaks still finds it in git *history* even after it's removed from HEAD — `trivy image` finds the secret baked into the image layer, and a Gitleaks pre-commit hook blocks a new commit that contains a secret.

No solution below — just the target shape. Build both parts, then check yourself against Verification and the Reference solution.

## Build it (guided)

### Part A — Encrypt Secrets at rest in etcd (`data-encrypt`)

By default kind/kubeadm store Secrets in etcd **unencrypted** (only base64-encoded). We'll prove it, then close the gap — the OSS equivalent of "storage/SQL encryption at rest," with the DEK provider standing in for a CMK.

1. **Plant a canary.** Create a Secret whose value you'll go hunting for in etcd:
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
3. **Goal: turn on etcd encryption for Secrets.** The apiserver loads an `EncryptionConfiguration` via `--encryption-provider-config`. Yours needs:
   - `resources: ["secrets"]` — scope it to Secret objects (matches `data-encrypt`).
   - A provider list where **order matters**: the *first* provider is the one used to encrypt new writes; every other entry is only consulted when reading data written under an older config.
   - An `aescbc` provider with a real, locally-held 32-byte key — your stand-in for a CMK/KMS DEK.
   - `identity: {}` still listed (usually last) so the apiserver can keep *reading* Secrets that predate encryption.

   Hint: [`lab-infra/encryption/encryption-config.yaml.example`](../lab-infra/encryption/encryption-config.yaml.example) is the exact template — its comments walk through every field above, including how to generate the key (`head -c 32 /dev/urandom | base64`). You don't have to hand-write this cold: `cd lab-infra/encryption && ./up.sh` seeds `encryption-config.yaml` from that template and auto-generates the key for you the first time it runs, then copies the file onto the node — but it deliberately stops there and will not touch the live apiserver for you.

   **Your turn:** run `./up.sh`, read what it prints, then do the part it leaves manual — hand-edit `/etc/kubernetes/manifests/kube-apiserver.yaml` **on the node** to add the `--encryption-provider-config` flag plus the matching `volumeMount`/`hostPath` volume it lists. Saving the file makes the kubelet restart the apiserver for you automatically.

   > Production hardening: replace the local `aescbc` key with a **KMS provider** backed by Vault transit / an HSM — the true CMK model, where the apiserver calls out to Vault to wrap the data-encryption key. That's `key-transit` (see [d2-cert-manager](d2-cert-manager.md) Part A) wired into the KMS plugin.
4. **Goal: make the change retroactive.** The config you just wired only encrypts *future* writes — the `canary` Secret from step 1 is still sitting in etcd as plaintext. Figure out the one-liner that round-trips every existing Secret through the API so the apiserver rewrites each one under the new (encrypting) config. Hint: it's a `kubectl get ... -o json` piped into a `kubectl` verb that writes objects back — no new manifest required.
5. **Read it out of etcd again — AFTER.** Same command as step 2, same key. Before you run it, predict what the value should look like now — then confirm:
   ```bash
   docker exec -it oss500-control-plane sh -c '
     ETCDCTL_API=3 etcdctl \
       --cacert /etc/kubernetes/pki/etcd/ca.crt \
       --cert   /etc/kubernetes/pki/etcd/server.crt \
       --key    /etc/kubernetes/pki/etcd/server.key \
       get /registry/secrets/oss500-apps/canary | strings'
   ```
6. Confirm the app path still works transparently (the apiserver decrypts on read):
   ```bash
   kubectl -n oss500-apps get secret canary -o jsonpath='{.data.token}' | base64 -d
   ```
   Same secret, same API — but at rest it should now be ciphertext, not the plaintext from step 2. (Volumes: encrypt PV-backed data with LUKS/`StorageClass` encryption; application data: Vault transit from the cert lab.)

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
8. **Goal: catch it in the filesystem.** Trivy can scan a filesystem tree for secret-shaped strings (AWS keys, private keys, tokens, ...) the same binary you'd use for CVE scanning. Your turn: find the Trivy subcommand and the flag that switches its scanner from vulnerabilities to secrets, and point it at `/tmp/secretscan-demo`. Expect a `HIGH`-severity finding on `app.py:1`.
9. **Goal: catch it baked into an image.** Build an image that embeds the same kind of secret — one as an `ENV` var, one written into a layer via `RUN` — then run Trivy's *image* scanner (not the filesystem one) against it. Your turn: write a two-line Dockerfile, build it, then scan it with the secret scanner turned on.
10. **Goal: catch it in git history, not just HEAD.** Gitleaks scans commits, so it finds a secret even after it's deleted from the working tree. Your turn: run Gitleaks against the demo repo from step 7 and produce a machine-readable report (hint: look for report-format/report-path flags), and check the process exit code — a scanner that finds a secret should fail the build, not just print a warning.
11. **Goal: stop it before it's ever committed.** Wire Gitleaks into a pre-commit hook so `git commit` itself refuses a commit containing a secret — shift-left instead of catch-later. Your turn: add a `.pre-commit-config.yaml` that hooks in the `gitleaks` repo at a pinned version, then `pre-commit install` and try committing a secret to confirm it's blocked.
    Remediation the exam wants (same as Defender): **move the secret into the vault + rotate the exposed credential + prefer workload identity** so there's no static secret at all — exactly [d2-vault-k8s-injection](d2-vault-k8s-injection.md).

## Verification

- **Encryption at rest**: the *same* etcd key `/registry/secrets/oss500-apps/canary` shows readable plaintext (`SUPERSECRET-PLAINTEXT-123`) **before** the EncryptionConfiguration and shows the `k8s:enc:aescbc:v1:key1:` ciphertext prefix **after** — while `kubectl get secret` still returns the value transparently.
- **Secret scanning**: `trivy fs --scanners secret` and `gitleaks detect` each emit a finding for the planted AWS key (Gitleaks flags it in git *history*, not just the worktree), and `trivy image` finds the secret baked into `leaky:demo`. The Gitleaks pre-commit hook blocks a new commit containing a secret.

## Reference solution

Build it yourself first; check after.

### Part A — etcd encryption at rest

1. Canary secret:
   ```bash
   kubectl -n oss500-apps create secret generic canary --from-literal=token=SUPERSECRET-PLAINTEXT-123
   ```
2. Read it — BEFORE:
   ```bash
   docker exec -it oss500-control-plane sh -c '
     ETCDCTL_API=3 etcdctl \
       --cacert /etc/kubernetes/pki/etcd/ca.crt \
       --cert   /etc/kubernetes/pki/etcd/server.crt \
       --key    /etc/kubernetes/pki/etcd/server.key \
       get /registry/secrets/oss500-apps/canary | strings'
   # ...you can READ  SUPERSECRET-PLAINTEXT-123  right there in etcd. Base64 != encryption.
   ```
3. The `EncryptionConfiguration` — the deployable artifact lives in [`lab-infra/encryption/encryption-config.yaml.example`](../lab-infra/encryption/encryption-config.yaml.example) (copy to `encryption-config.yaml` and paste a real key — `./up.sh` does this seeding + key generation for you). Its shape, provider order matters:
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

   Bring it up, then hand-wire the apiserver (the manual manifest edit `up.sh` prints — add the `--encryption-provider-config` flag plus the `enc` volume/volumeMount):
   ```bash
   cd lab-infra/encryption && ./up.sh          # installs config + prints the kube-apiserver manifest edits
   ```
4. Re-encrypt existing Secrets — the config only encrypts *future* writes; force-rewrite everything so the old plaintext `canary` gets encrypted too:
   ```bash
   kubectl get secrets --all-namespaces -o json | kubectl replace -f -
   ```
5. Read it out of etcd again — AFTER. Same key, now ciphertext:
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

### Part B — secret scanning

7. Plant secrets:
   ```bash
   mkdir -p /tmp/secretscan-demo && cd /tmp/secretscan-demo && git init -q
   cat > app.py <<'EOF'
   AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
   AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
   EOF
   git add app.py && git commit -qm "add app"      # secret is now in history, not just the worktree
   ```
8. Trivy — filesystem secret scan:
   ```bash
   trivy fs --scanners secret /tmp/secretscan-demo
   # HIGH  AWS Access Key ID  app.py:1  ...
   ```
9. Trivy — image secret scan (bake a secret into an image, then scan the layers):
   ```bash
   printf 'FROM alpine:3.20\nENV DB_PASSWORD=hunter2-prod\nRUN echo "AKIAIOSFODNN7EXAMPLE" > /root/.aws_key\n' > Dockerfile
   docker build -t leaky:demo .
   trivy image --scanners secret leaky:demo
   # detects the AWS key in the layer / the ENV secret
   ```
10. Gitleaks — scan git history (catches secrets even after they're deleted from HEAD):
    ```bash
    gitleaks detect --source /tmp/secretscan-demo --verbose --report-format json --report-path /tmp/gitleaks.json
    # Finding: AWS ... commit <sha> app.py  -> nonzero exit code (fails CI)
    ```
11. Shift left — pre-commit hook so secrets never get committed in the first place:
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

If your `EncryptionConfiguration` lists `identity` before `aescbc`, new Secrets never actually get encrypted even though the apiserver loads the config without error — provider order is the whole mechanism, not a formality. And if you skip the `kubectl get secrets -A -o json | kubectl replace -f -` rewrite, only Secrets written *after* the change are encrypted; anything written earlier (like `canary`) sits in etcd as plaintext indefinitely.

## Teardown

- `cd lab-infra/encryption && ./down.sh`
- `rm -rf /tmp/secretscan-demo && docker rmi leaky:demo`

## What the exam asks

- A Kubernetes `Secret` is **base64, not encrypted, at rest by default** — the fix is an `EncryptionConfiguration` on the apiserver (etcd encryption), the analogue of storage/SQL encryption at rest. Enabling it only encrypts **future** writes; existing objects need a `kubectl get ... | kubectl replace -f -` rewrite.
- The **provider order** matters: the first provider encrypts new writes; `identity` must stay available (usually last) to read older data. A KMS provider (→ Vault/HSM) is the **customer-managed key (CMK)** model, versus a locally-held `aescbc` key.
- **Encryption vs secret scanning** solve different problems: encryption protects data *inside* the store; scanning finds secrets that **leaked outside** it (code, images, disks). CMK/at-rest questions ≠ secret-sprawl questions.
- **Gitleaks scans git history**, so a secret is exposed the moment it is committed *even if later removed* — the remediation is always **rotate the credential**, not just delete the line. Shift-left with a pre-commit hook + a CI scan (Trivy/Gitleaks) is the preventive control.
- Trivy does double duty: vulnerability *and* secret scanning of both filesystems and images (`--scanners secret`).
