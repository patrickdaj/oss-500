# Lab d3: Software supply chain — scan, sign, gate

Fail a build on a CRITICAL CVE, generate and attach an SBOM, sign an image with cosign, push it to Harbor, then have Kyverno reject an unsigned image at admission and admit the signed one.

**Objectives covered**

| id | Objective |
|---|---|
| `sc-scan` | Scan images and dependencies for vulnerabilities |
| `sc-registry` | Secure a private registry and sign/verify images |
| `sc-sbom` | Generate and evaluate SBOMs for deployed artifacts |
| `sc-admission` | Gate admission on scan results and signature verification |

**SC-500 correspondence**: Defender vulnerability management (image scanning in ACR/AKS), Azure Container Registry + content trust / image signing, and Azure Policy for AKS (allowed images, signature/integrity gate).

**Prerequisites**
- kind cluster + [`lab-infra/shared`](../lab-infra/shared/) up; [`lab-infra/governance`](../lab-infra/governance/) up for Kyverno (Part D).
- [`lab-infra/supplychain`](../lab-infra/supplychain/) up (`./up.sh`) — Harbor. Trivy/Grype/Syft/cosign are CLIs (`brew install trivy grype syft cosign` or the container forms).
- Notes read: [supply-chain.md](../domains/3-compute-ai/supply-chain.md)

**Estimated time**: 2–2.5 h · $0 (local)

## Steps

### Part A — Scan and fail on vulnerabilities (`sc-scan`)

1. Scan a deliberately old image and let the exit code gate it:
   ```bash
   trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 python:3.8-slim; echo "exit=$?"
   ```
   → prints CRITICAL findings and **`exit=1`** — in CI this fails the pipeline. That non-zero exit *is* the control.
2. Cross-check with Grype: `grype python:3.8-slim --fail-on critical; echo "exit=$?"` → also non-zero. Two engines, same gate.
3. Show tuning: `trivy image --severity CRITICAL python:3.8-slim` (no `--exit-code`) is a *report*, not a gate. Add a `.trivyignore` with one CVE + a comment and re-run to see it accepted — the documented-exception ledger.

### Part B — Generate and scan an SBOM (`sc-sbom`)

4. Generate an SBOM with Syft in both standard formats:
   ```bash
   syft python:3.8-slim -o spdx-json=app.spdx.json -o cyclonedx-json=app.cdx.json
   ```
5. Scan the SBOM directly (no image re-pull needed) — proving an SBOM answers exposure questions on its own:
   ```bash
   grype sbom:./app.spdx.json
   ```
6. Note the payoff: with SBOMs stored, "which artifacts contain openssl < X" is one query, not a fleet rebuild.

### Part C — Sign and push to Harbor (`sc-registry`)

7. Log into Harbor (admin password from your `harbor-admin.secret` copied from the `.example`) and create a project `lib`. `docker login harbor.oss500.local`.
8. Tag and push a small image: `docker tag alpine:3.20 harbor.oss500.local/lib/alpine:3.20 && docker push harbor.oss500.local/lib/alpine:3.20`. Harbor's built-in Trivy scans it on push — view the CVE report in the UI (continuous scanning, the registry-side gate).
9. Sign it with cosign:
   ```bash
   cosign generate-key-pair                    # cosign.key / cosign.pub
   cosign sign --key cosign.key harbor.oss500.local/lib/alpine:3.20
   cosign verify --key cosign.pub harbor.oss500.local/lib/alpine:3.20; echo "exit=$?"
   ```
   → verify **exits 0**. Tamper test: `cosign verify` a different, unsigned tag → **non-zero / no matching signatures**.
10. Attach the SBOM as a signed attestation so inventory + provenance travel with the image: `cosign attest --key cosign.key --predicate app.cdx.json --type cyclonedx harbor.oss500.local/lib/alpine:3.20`.

### Part D — Gate admission on signature (`sc-admission`)

11. Apply the Kyverno image-verification policy (public key from step 9):
    ```bash
    kubectl apply -f lab-infra/supplychain/kyverno/require-signed-images.yaml
    ```
12. Try to run an **unsigned** image from Harbor: `kubectl -n oss500-apps run u --image=harbor.oss500.local/lib/unsigned:x --restart=Never` → **rejected by Kyverno** (`image is not signed` / failed attestor check).
13. Run the **signed** image: `kubectl -n oss500-apps run s --image=harbor.oss500.local/lib/alpine:3.20 --restart=Never` → **admitted**. Cluster-side gate proven, on top of Harbor's registry-side gate.

## Verification
- Trivy and Grype **exit non-zero** on a CRITICAL CVE, failing the gate; a report without a threshold does not (Part A).
- An SBOM is produced in **SPDX and CycloneDX** and scanned directly with Grype (Part B).
- `cosign verify` **exits 0 for the signed image and fails for an unsigned/tampered one**; Harbor shows the push-time scan report (Part C).
- Kyverno **rejects the unsigned image and admits the cosign-signed one** at admission (Part D).

## Teardown
- `kubectl -n oss500-apps delete pod s u --ignore-not-found; kubectl delete clusterpolicy require-signed-images --ignore-not-found`
- `cd lab-infra/supplychain && ./down.sh`

## What the exam asks
- The gate is the **exit code** (`--exit-code 1` / `--fail-on`). `--ignore-unfixed` is a policy choice (don't fail on unactionable vulns); scan at build *and* continuously in the registry.
- Signing (cosign) proves **authenticity/integrity**, not vuln-freedom — a signed image can still be full of CVEs. You need scanning *and* signing.
- SBOM formats: **SPDX** and **CycloneDX**. An SBOM is an inventory; you scan it to get vulnerabilities.
- Two enforcement points: Harbor blocks the *pull* (severity threshold / signature policy); Kyverno `verifyImages` (cosign) blocks the *schedule*. The OSS Azure Policy for AKS + ACR content trust.
