# Protect data at rest and detect exposed secrets

Domain 2, subsection 5 (`d2-data`). Two data-protection duties: **encrypt data at rest** so a stolen etcd snapshot or disk yields nothing (Kubernetes EncryptionConfiguration, optionally KMS-backed by Vault), and **detect plaintext secrets** that have already sprawled into repos and images (Trivy, Gitleaks). Primary lab: [d2-data-protection](../../labs/d2-data-protection.md); environment in [`lab-infra/encryption/`](../../lab-infra/encryption/).

## Encrypt data at rest: etcd secrets, volumes, and application data

*Objective: `data-encrypt` · OSS: etcd encryption / Vault transit ≈ SC-500: Storage/SQL encryption, CMK · Lab: [d2-data-protection](../../labs/d2-data-protection.md)*

A Kubernetes Secret is only **base64-encoded** in etcd (see [fundamentals](../0-fundamentals/02-kubernetes.md)) — anyone with the etcd data file or a backup reads every secret in cleartext. **Encryption at rest** fixes this: the kube-apiserver encrypts resources (notably `secrets`) before writing them to etcd, using an **EncryptionConfiguration** passed via `--encryption-provider-config`. Providers, in ascending strength: `identity` (none), `aesgcm`/`aescbc`/`secretbox` (local key in the config file), and `kms` (v2) which delegates to an **external KMS** — and **Vault's transit engine** (`key-transit`) can be that KMS, so the data key that wraps etcd secrets lives in Vault, never on the API-server disk. This is the OSS realization of a **customer-managed key (CMK)**.

Mechanically, KMS **v2** is the one you want. It uses **envelope encryption**: the API server generates a local **DEK** (data-encryption key) per write, encrypts the resource with it (AES-GCM), then asks the external KMS to wrap that DEK under a **KEK** the KMS holds — the same DEK-under-KEK chain the transit `datakey` API produces (`key-transit`). v2 (stable since Kubernetes 1.29) caches the wrapped DEK, so it makes far fewer calls to the KMS plugin than the deprecated v1, and it exposes a `key_id` so you can observe KEK rotation and trigger re-encryption. The KMS plugin runs as a small gRPC service on a UNIX socket next to the API server (for Vault this is a KMS-plugin shim that calls `transit/encrypt`/`transit/decrypt`).

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

Beyond etcd there are two more layers, forming a **defense-in-depth** stack: **volume encryption** (LUKS/dm-crypt under a StorageClass, so PersistentVolumes are encrypted on disk) and **application-layer encryption** with Vault transit (the app encrypts fields before they ever hit the DB, so even a DB admin or a stolen DB dump sees only `vault:v1:` ciphertext). Layer them by threat: etcd encryption defends a stolen etcd snapshot, LUKS defends a stolen disk/PV, and transit field encryption defends a compromised database. Against SC-500 this whole objective is **storage/SQL encryption + CMK**: Azure Storage/SQL encrypt at rest by default with platform (Microsoft-managed) keys, and CMK lets you supply a Key Vault key with double-encryption (infrastructure + service layer) — the `kms`-provider + Vault chain here is that CMK model for Kubernetes, and the transit app-layer encryption is the equivalent of Always Encrypted / column-level protection.

Common failure modes:

- **Secrets stay plaintext after you enable encryption.** The config only affects *new* writes; you forgot the `kubectl get secrets -A -o json | kubectl replace -f -` re-encrypt pass, so old rows are still `k8s:enc:identity` (i.e. cleartext base64).
- **`identity` placed first** silently disables encryption — it matches everything on write and stores plaintext. It must be *last*, as the read-only fallback.
- **KMS plugin down = API server can't decrypt.** If the Vault KMS socket is unreachable, reads of encrypted secrets fail; a healthz check on the plugin is mandatory, and losing the Vault KEK with no backup means the encrypted etcd data is unrecoverable.
- **Key in the config file** — with local `aesgcm`/`aescbc`, the KEK sits in `--encryption-provider-config` on the control-plane disk (mode 0600, root-owned). Anyone who can read that file *and* an etcd backup defeats the encryption; this is exactly why `kms`+Vault is stronger.

Exam gotchas:

- Kubernetes Secrets are **base64, not encrypted** by default — encryption at rest requires an explicit `EncryptionConfiguration` on the API server. This is exactly the gap the [fundamentals note](../0-fundamentals/02-kubernetes.md) flagged.
- Enabling encryption doesn't rewrite existing secrets — you must `kubectl replace` them; the `k8s:enc:` prefix in raw etcd proves it worked.
- Provider **order** = the first encrypts on write; keep `identity` last (never first) so previously-written data still decrypts during migration.
- `kms` (v2) with Vault transit = customer-managed-key equivalent (key outside the API-server disk, envelope-encrypted DEK-under-KEK); local `aescbc`/`secretbox` keeps the key *in* the config file (better than nothing, weaker than KMS). Prefer **AES-GCM** over the older CBC providers for authenticated encryption.
- Encryption at rest is **not** encryption in transit — etcd peer/client TLS and the `net-mesh`/`net-ingress` TLS are separate controls; the exam tests that you can name which layer defends which threat.

**Resources:**
- [Encrypting confidential data at rest (Kubernetes)](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/) (~20 min)
- [Using a KMS provider for data encryption](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/) (~15 min)
- [KMS v2 improvements (Kubernetes blog)](https://kubernetes.io/blog/2023/05/16/kms-v2-moving-to-beta/) (~12 min)
- [Vault transit datakey & envelope encryption](https://developer.hashicorp.com/vault/docs/secrets/transit#datakey) (~10 min)
- [NIST SP 800-57 Part 1 — key management recommendations](https://csrc.nist.gov/pubs/sp/800/57/pt1/r5/final) (~30 min, reference)
- [LUKS / dm-crypt cryptsetup FAQ](https://gitlab.com/cryptsetup/cryptsetup/-/wikis/FrequentlyAskedQuestions) (~15 min, reference)

## Scan repositories and images for plaintext secrets

*Objective: `data-secretscan` · OSS: Trivy / Gitleaks ≈ SC-500: Defender CSPM secret scanning · Lab: [d2-data-protection](../../labs/d2-data-protection.md)*

Encryption protects secrets you *manage*; the other failure mode is secrets that leaked into places they never belonged — hardcoded in source, baked into a container image layer, left in git history. Two OSS scanners find them. **Trivy** scans filesystems, container images, and repos for embedded secrets (and vulns/misconfig/SBOM) via its secret scanner, which matches against a built-in set of regex rules plus entropy heuristics; **Gitleaks** specializes in git — scanning the working tree *and full commit history*, and running as a pre-commit hook so a secret never gets committed in the first place. Both emit **SARIF**, so findings drop straight into GitHub code-scanning / the Domain 4 SIEM.

```bash
# Trivy — secret scan a working directory, and a built image's layers
trivy fs --scanners secret .
trivy image --scanners secret myapp:latest        # finds keys baked into image layers
trivy fs --scanners secret,vuln,misconfig --exit-code 1 .   # fail CI on any finding

# Gitleaks — scan history (detect) and staged changes (protect / pre-commit)
gitleaks detect --source . --report-format sarif --report-path leaks.sarif
gitleaks protect --staged                          # blocks the commit if a secret is staged
```

```yaml
# .pre-commit-config.yaml — block secrets before they ever reach a commit
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.4
    hooks:
      - id: gitleaks
```

Trivy's secret finding names the rule (e.g., `aws-access-key-id`), file, and line; Gitleaks reports the commit, author, date, and rule id. Tune both with an allowlist (`.gitleaks.toml` / `trivy-secret.yaml`) to suppress **test fixtures and known-fake keys** — but never a real one. Wire either into CI (fail the build on a finding, `--exit-code 1` / non-zero on leak) and Gitleaks into a **pre-commit hook** for shift-left prevention. The remediation is never "delete the finding": **rotate the exposed credential** (assume it's burned the moment it hit a shared branch or a pushed image), scrub it from history (`git filter-repo` / BFG), and move it into Vault (`vault-*`) referenced via the injector (`vault-k8s`).

This is the OSS answer to **Defender CSPM secret scanning** (and GitHub Advanced Security secret scanning + push protection), which agentlessly finds plaintext secrets on VM disks, in cloud deployments, and in connected DevOps repos. Trivy/Gitleaks cover the repo/image surface; the SC-500 remediation pattern is identical — **rotate + move to the vault + prefer managed/dynamic identity so there's no static secret at all**.

Exam gotchas:

- Secret scanning finds secrets **already leaked** into code/images/history — a different problem from encrypting the secrets you manage in Vault/etcd. Both matter, and the exam pairs them as detection vs. protection.
- Gitleaks scans **full git history**, so deleting a secret in the latest commit doesn't clear it — a past commit still exposes it. History rewrite + rotation is required; the credential is *already compromised*.
- The fix is always **rotate the exposed credential** (treat it as burned) + vault it — never just suppress the finding or `.gitignore` the file.
- Run scanners in **CI (fail the build)** and as a **pre-commit hook (block the commit)** — detection plus prevention, the shift-left equivalent of CSPM/push-protection catching it in the pipeline.
- `trivy image` inspects **each layer** — a secret `COPY`'d in and later `rm`'d still lives in the earlier layer and is found; the fix is a multi-stage build or `--secret` mounts, not a later delete.

**Resources:**
- [Trivy secret scanning](https://trivy.dev/latest/docs/scanner/secret/) (~15 min)
- [Gitleaks (GitHub, README + config)](https://github.com/gitleaks/gitleaks) (~15 min)
- [Trivy CI/CD integration & exit codes](https://trivy.dev/latest/docs/configuration/) (~10 min)
- [git filter-repo — removing sensitive data from history](https://github.com/newren/git-filter-repo) (~15 min)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) (~20 min)
- [pre-commit framework — Quick start (install & configure hooks)](https://pre-commit.com/#quick-start) (~10 min)

## Summary

| Objective | Takeaway |
|---|---|
| `data-encrypt` | Secrets are base64 in etcd until an `EncryptionConfiguration` (`aescbc`/`secretbox`/`kms`) encrypts them; re-encrypt existing with `kubectl replace`; `kms`+Vault transit = CMK; add volume + app-layer encryption |
| `data-secretscan` | Trivy (fs/image/repo) and Gitleaks (git history + pre-commit) find leaked plaintext secrets; fix = rotate + vault + shift-left in CI ≈ Defender CSPM secret scanning |
