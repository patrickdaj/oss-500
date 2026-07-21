# Protect data at rest and detect exposed secrets

Domain 2, subsection 5 (`d2-data`). Two data-protection duties: **encrypt data at rest** so a stolen etcd snapshot or disk yields nothing (Kubernetes EncryptionConfiguration, optionally KMS-backed by Vault), and **detect plaintext secrets** that have already sprawled into repos and images (Trivy, Gitleaks). Primary lab: [d2-data-protection](../../labs/d2-data-protection.md); environment in [`lab-infra/encryption/`](../../lab-infra/encryption/).

## Encrypt data at rest: etcd secrets, volumes, and application data

*Objective: `data-encrypt` · OSS: etcd encryption / Vault transit ≈ SC-500: Storage/SQL encryption, CMK · Lab: [d2-data-protection](../../labs/d2-data-protection.md)*

A Kubernetes Secret is only **base64-encoded** in etcd (see [fundamentals](../0-fundamentals/02-kubernetes.md)) — anyone with the etcd data file or a backup reads every secret in cleartext. **Encryption at rest** fixes this: the kube-apiserver encrypts resources (notably `secrets`) before writing them to etcd, using an **EncryptionConfiguration** passed via `--encryption-provider-config`. Providers, in ascending strength: `identity` (none), `aescbc`/`secretbox` (local key in the config file), and `kms` (v2) which delegates to an **external KMS** — and **Vault's transit engine** (`key-transit`) can be that KMS, so the data key that wraps etcd secrets lives in Vault, never on the API-server disk. This is the OSS realization of a **customer-managed key (CMK)**.

```yaml
# EncryptionConfiguration — encrypt Secrets with an AES-CBC key (kms provider for CMK-grade)
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources: ["secrets"]
    providers:
      - aescbc:                       # data-encrypt: local key; use `kms` (Vault) for a real CMK
          keys:
            - name: key1
              secret: <base64-32-byte-key>
      - identity: {}                  # fallback so pre-existing plaintext secrets still read
```

Order matters: the **first** provider encrypts on write; `identity` last lets old plaintext values still decrypt. After enabling it you must **re-encrypt existing secrets** — they aren't rewritten until touched:

```bash
kubectl get secrets -A -o json | kubectl replace -f -   # force rewrite → now encrypted in etcd
# Prove it: read the raw etcd value; encrypted secrets are prefixed k8s:enc:aescbc:v1:
kubectl -n kube-system exec etcd-<node> -- etcdctl get /registry/secrets/oss500-apps/app --print-value-only
```

Beyond etcd there are two more layers: **volume encryption** (LUKS/dm-crypt under a StorageClass, so PersistentVolumes are encrypted on disk) and **application-layer encryption** with Vault transit (the app encrypts fields before they ever hit the DB). Against SC-500 this whole objective is **storage/SQL encryption + CMK**: Azure Storage/SQL encrypt at rest by default with platform keys, and CMK lets you supply a Key Vault key — the `kms`-provider + Vault chain here is that CMK model for Kubernetes.

Exam gotchas:

- Kubernetes Secrets are **base64, not encrypted** by default — encryption at rest requires an explicit `EncryptionConfiguration` on the API server. This is exactly the gap the [fundamentals note](../0-fundamentals/02-kubernetes.md) flagged.
- Enabling encryption doesn't rewrite existing secrets — you must `kubectl replace` them; the `k8s:enc:` prefix in raw etcd proves it worked.
- Provider **order** = the first encrypts on write; keep `identity` last (never first) so previously-written data still decrypts during migration.
- `kms` (v2) with Vault transit = customer-managed-key equivalent (key outside the API-server disk); local `aescbc`/`secretbox` keeps the key *in* the config file (better than nothing, weaker than KMS).

**Resources:**
- [Encrypting Secret data at rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/) (~20 min)
- [Using a KMS provider for data encryption](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/) (~15 min)

## Scan repositories and images for plaintext secrets

*Objective: `data-secretscan` · OSS: Trivy / Gitleaks ≈ SC-500: Defender CSPM secret scanning · Lab: [d2-data-protection](../../labs/d2-data-protection.md)*

Encryption protects secrets you *manage*; the other failure mode is secrets that leaked into places they never belonged — hardcoded in source, baked into a container image layer, left in git history. Two OSS scanners find them. **Trivy** scans filesystems, container images, and repos for embedded secrets (and vulns/misconfig) via its secret scanner; **Gitleaks** specializes in git — scanning the working tree *and full commit history*, and running as a pre-commit hook so a secret never gets committed in the first place.

```bash
# Trivy — secret scan a working directory, and a built image's layers
trivy fs --scanners secret .
trivy image --scanners secret myapp:latest        # finds keys baked into image layers

# Gitleaks — scan history (detect) and staged changes (protect / pre-commit)
gitleaks detect --source . --report-format sarif --report-path leaks.sarif
gitleaks protect --staged                          # blocks the commit if a secret is staged
```

Trivy's secret finding names the rule (e.g., `aws-access-key-id`), file, and line; Gitleaks reports the commit, author, and rule. Wire either into CI (fail the build on a finding) and Gitleaks into a **pre-commit hook** for shift-left prevention. The remediation is never "delete the finding": **rotate the exposed credential** (assume it's burned), remove it from history (`git filter-repo`), and move it into Vault (`vault-*`) referenced via the injector (`vault-k8s`).

This is the OSS answer to **Defender CSPM secret scanning**, which agentlessly finds plaintext secrets on VM disks, in cloud deployments, and in connected DevOps repos. Trivy/Gitleaks cover the repo/image surface; the SC-500 remediation pattern is identical — **rotate + move to the vault + prefer managed/dynamic identity so there's no static secret at all**.

Exam gotchas:

- Secret scanning finds secrets **already leaked** into code/images/history — a different problem from encrypting the secrets you manage in Vault/etcd. Both matter.
- Gitleaks scans **full git history**, so deleting a secret in the latest commit doesn't clear it — a past commit still exposes it. History rewrite + rotation is required.
- The fix is always **rotate the exposed credential** (treat it as compromised) + vault it — never just suppress the finding.
- Run scanners in **CI (fail the build)** and as a **pre-commit hook (block the commit)** — detection plus prevention, the shift-left equivalent of CSPM catching it in the pipeline.

**Resources:**
- [Trivy secret scanning](https://trivy.dev/latest/docs/scanner/secret/) (~15 min)
- [Gitleaks (github)](https://github.com/gitleaks/gitleaks) (~15 min)

## Summary

| Objective | Takeaway |
|---|---|
| `data-encrypt` | Secrets are base64 in etcd until an `EncryptionConfiguration` (`aescbc`/`secretbox`/`kms`) encrypts them; re-encrypt existing with `kubectl replace`; `kms`+Vault transit = CMK; add volume + app-layer encryption |
| `data-secretscan` | Trivy (fs/image/repo) and Gitleaks (git history + pre-commit) find leaked plaintext secrets; fix = rotate + vault + shift-left in CI ≈ Defender CSPM secret scanning |
