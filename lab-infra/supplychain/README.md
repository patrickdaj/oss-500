# lab-infra/supplychain — Harbor + Trivy + cosign

The software supply-chain stack (`d3-supplychain` → `sc-scan`, `sc-registry`, `sc-sbom`, `sc-admission`). Mirrors **Azure Container Registry + Defender vulnerability management + content trust**: a governed private registry with built-in continuous scanning, image signing, SBOM/attestation, and admission gating.

## What this brings up

| Component | Form | Role | Objective |
|---|---|---|---|
| Harbor | `harbor/harbor` Helm chart | private OCI registry, RBAC, built-in Trivy scan, signature policy | `sc-registry` |
| Trivy | CLI + Kubernetes `Job` | image/dependency CVE scanning, SBOM | `sc-scan`, `sc-sbom` |
| Grype / Syft | CLI (Anchore) | alt scanner + SBOM generator | `sc-scan`, `sc-sbom` |
| cosign | CLI (Sigstore) | sign/verify images, attach attestations | `sc-registry` |
| Kyverno policy | `ClusterPolicy` | verify signatures at admission | `sc-admission` |

Harbor runs in the **`oss500-apps`** namespace. Trivy/Grype/Syft/cosign are **CLIs** (`brew install trivy grype syft cosign`, or their container images) — nothing to keep resident; a Trivy scan can also run as a one-shot `Job` (`trivy/scan-job.yaml`) so CI-style scanning is reproducible in-cluster. The Kyverno `verifyImages` policy is applied from here but Kyverno itself comes from [`lab-infra/governance`](../governance/).

## Layout

```
supplychain/
├── README.md
├── up.sh                              # helm install harbor; wait ready
├── down.sh                            # helm uninstall + PVC cleanup
├── harbor/values.yaml                 # ingress host, admin pass ref, built-in Trivy on
├── trivy/scan-job.yaml                # one-shot Trivy scan Job (sc-scan)
├── kyverno/require-signed-images.yaml # cosign signature gate at admission (sc-admission)
└── harbor-admin.secret.example        # copy → .secret; Harbor admin password (gitignored)
```

## Usage

```bash
cd lab-infra/supplychain
cp harbor-admin.secret.example harbor-admin.secret     # set a strong admin password
./up.sh
# Add harbor.oss500.local to /etc/hosts pointing at 127.0.0.1 (kind ingress on :8080/:8443)
# ...perform labs/d3-supply-chain.md: scan, SBOM, sign, gate...
./down.sh
```

The registry is reachable at `harbor.oss500.local` via the shared ingress (kind maps `:8080/:8443` to localhost). Because it's a self-signed local CA, `docker`/`cosign` need the CA trusted or `--insecure`/`--allow-insecure-registry` for the lab (documented in the lab steps).

## Two enforcement points (the design point)

- **Registry-side** (Harbor): "prevent vulnerable images from running" severity threshold per project, plus a cosign content-trust policy — blocks the *pull*.
- **Cluster-side** (Kyverno `verifyImages`): rejects unsigned/unapproved-registry images — blocks the *schedule*.

Defense in depth uses both; `labs/d3-supply-chain.md` proves each independently.

## Secrets hygiene

`harbor-admin.secret` and any generated `cosign.key` are gitignored — only `harbor-admin.secret.example` is committed. cosign private keys never enter git; prefer keyless (OIDC + Rekor) where a keypair isn't needed.
