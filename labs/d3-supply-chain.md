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
- Tools for this lab: `trivy`, `grype`, `syft`, `cosign` — install per [`../TOOLS.md`](../TOOLS.md).

**Estimated time**: 2–2.5 h · $0 (local)

## Challenge

Take one deliberately old, CVE-riddled image through the full software-supply-chain gate — four checkpoints, each with its own observable to reach:

- **Scan (`sc-scan`)** — a CRITICAL finding must fail the build, not just print a report: the scanner **exits non-zero**.
- **SBOM (`sc-sbom`)** — produce a real inventory of the image's contents in **both SPDX and CycloneDX**, then answer a vulnerability question from the SBOM alone, with no image re-pull.
- **Sign & push (`sc-registry`)** — push to Harbor (scanned automatically on push), then sign the image so anyone can cryptographically prove it came from you and is unmodified: `cosign verify` must **exit 0 for the signed image and fail for anything unsigned or tampered**.
- **Admission gate (`sc-admission`)** — make the cluster itself refuse to run an unsigned image and admit only the signed one: Kyverno **rejects the unsigned pod and admits the signed one**, stacked on top of Harbor's registry-side block.

No finished commands below — goals and hints are all you get. Assemble the flags, keys, and manifest edits yourself, then check against the Reference solution.

## Build it (guided)

### Part A — Scan and fail on vulnerabilities (`sc-scan`)

1. **Turn a report into a gate.** Scan `python:3.8-slim` (deliberately old) with Trivy so that finding a CRITICAL vulnerability makes the command itself fail, the way a CI job would. Hint: `trivy image --help` has a severity filter, a flag to skip vulnerabilities with no available fix, and a flag that turns a printed table into a real gate via the process exit code. Your turn: run it and read the exit code — **that non-zero exit *is* the control**, not the table above it.
2. **Cross-check with a second engine.** Confirm the same verdict with Grype, which has its own "fail on this severity" flag — you're proving two independent engines agree on the same gate, not trusting one tool's exit-code semantics.
3. **Show the report/gate distinction on purpose.** Re-run Trivy against the same image *without* the exit-code flag — confirm it now just prints findings and returns 0 regardless. Then create a `.trivyignore` file with one accepted CVE ID plus a comment explaining why, and re-scan with the exit-code flag back on: that CVE should stop tripping the gate. This file is a **documented-exception ledger** — a place to record *why* something is accepted, not a quiet way to silence findings.

### Part B — Generate and scan an SBOM (`sc-sbom`)

4. **Generate both standard formats in one run.** Use Syft against the same image to produce an SPDX SBOM and a CycloneDX SBOM — one command, two `-o format=file` outputs.
5. **Scan the SBOM, not the image.** Point Grype at the SBOM file itself (its `sbom:` scheme), not the image reference — no re-pull. This proves the SBOM alone is enough to answer "what's inside, and is any of it vulnerable."
6. **Why it matters:** once SBOMs are stored, "which artifacts contain openssl < X" becomes one query against your SBOM store, not a fleet-wide rebuild-and-rescan.

### Part C — Sign and push to Harbor (`sc-registry`)

7. Log into Harbor (admin password from your `harbor-admin.secret`, copied from the `.example`) and create a project `lib`. `docker login harbor.oss500.local`.
8. Tag and push a small image: `docker tag alpine:3.20 harbor.oss500.local/lib/alpine:3.20 && docker push harbor.oss500.local/lib/alpine:3.20`. Harbor's built-in Trivy scans it on push — view the CVE report in the UI (continuous scanning, the registry-side gate).
9. **Prove authenticity and integrity, not vuln-freedom.** Generate a cosign keypair, sign the pushed image with the private key, then verify it with the public key. Hint: look for a `generate-key-pair`, a `sign --key`, and a `verify --key` subcommand. Your turn: after confirming the signed tag verifies with exit 0, point `verify` at a *different*, unsigned tag and confirm it fails — the negative/tamper test is part of proving the control, not an afterthought.
10. **Attach the SBOM as a signed attestation.** Use cosign's attestation subcommand with the CycloneDX file from Part B as the predicate, so inventory and provenance travel with the image itself. Think about why an unsigned SBOM sitting next to the image on disk wouldn't give you the same guarantee.

### Part D — Gate admission on signature (`sc-admission`)

11. **Wire the cluster-side gate.** A starting Kyverno policy lives at [`lab-infra/supplychain/kyverno/require-signed-images.yaml`](../lab-infra/supplychain/kyverno/require-signed-images.yaml) — open it first. It verifies images under `harbor.oss500.local/*` against a `publicKeys` block that currently reads `REPLACE_WITH_COSIGN_PUB_FROM_LAB`. Paste in the `cosign.pub` you generated in step 9, then apply it. Before you do, read `validationFailureAction: Enforce` and `failurePolicy: Fail` in the manifest and reason through what each does if the Kyverno webhook itself is unreachable — which one makes this fail closed?
12. **Fire the negative case.** Try to run an **unsigned** image from Harbor as a bare pod — **in `oss500-demo`, not `oss500-apps`**: built-in PSA evaluates before Kyverno's `verifyImages` webhook, so a `restricted`-labeled namespace would reject a bare pod on PSS grounds regardless of signature, making the "admitted" case in the next step unreachable:
    ```bash
    kubectl -n oss500-demo run u --image=harbor.oss500.local/lib/unsigned:x --restart=Never
    ```
    Read the rejection Kyverno gives you — it should name the missing/failed signature check.
13. **Fire the positive case.** Run the **signed** image the same way:
    ```bash
    kubectl -n oss500-demo run s --image=harbor.oss500.local/lib/alpine:3.20 --restart=Never
    ```
    → admitted. You now have two independent, stacked gates: Harbor blocks at the *pull*, Kyverno blocks at the *schedule*.

## Verification
- Trivy and Grype **exit non-zero** on a CRITICAL CVE, failing the gate; a report without a threshold does not (Part A).
- An SBOM is produced in **SPDX and CycloneDX** and scanned directly with Grype (Part B).
- `cosign verify` **exits 0 for the signed image and fails for an unsigned/tampered one**; Harbor shows the push-time scan report (Part C).
- Kyverno **rejects the unsigned image and admits the cosign-signed one** at admission (Part D).

## Reference solution
Build it yourself first; check after.

**Part A — scan and fail:**
```bash
trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 python:3.8-slim; echo "exit=$?"
```
→ prints CRITICAL findings and **`exit=1`** — in CI this fails the pipeline. That non-zero exit *is* the control.
Cross-check with Grype: `grype python:3.8-slim --fail-on critical; echo "exit=$?"` → also non-zero. Two engines, same gate.
Show tuning: `trivy image --severity CRITICAL python:3.8-slim` (no `--exit-code`) is a *report*, not a gate. Add a `.trivyignore` with one CVE + a comment and re-run to see it accepted — the documented-exception ledger.

**Part B — SBOM generate and scan:**
```bash
syft python:3.8-slim -o spdx-json=app.spdx.json -o cyclonedx-json=app.cdx.json
```
Scan the SBOM directly (no image re-pull needed) — proving an SBOM answers exposure questions on its own:
```bash
grype sbom:./app.spdx.json
```
Payoff: with SBOMs stored, "which artifacts contain openssl < X" is one query, not a fleet rebuild.

**Part C — sign and push to Harbor:**
Log into Harbor (admin password from your `harbor-admin.secret` copied from the `.example`) and create a project `lib`. `docker login harbor.oss500.local`.
Tag and push a small image: `docker tag alpine:3.20 harbor.oss500.local/lib/alpine:3.20 && docker push harbor.oss500.local/lib/alpine:3.20`. Harbor's built-in Trivy scans it on push — view the CVE report in the UI (continuous scanning, the registry-side gate).
Sign it with cosign:
```bash
cosign generate-key-pair                    # cosign.key / cosign.pub
cosign sign --key cosign.key harbor.oss500.local/lib/alpine:3.20
cosign verify --key cosign.pub harbor.oss500.local/lib/alpine:3.20; echo "exit=$?"
```
→ verify **exits 0**. Tamper test: `cosign verify` a different, unsigned tag → **non-zero / no matching signatures**.
Attach the SBOM as a signed attestation so inventory + provenance travel with the image: `cosign attest --key cosign.key --predicate app.cdx.json --type cyclonedx harbor.oss500.local/lib/alpine:3.20`.

**Part D — gate admission on signature:**
The complete manifest — public key from step 9 pasted into the `publicKeys` block — lives at [`lab-infra/supplychain/kyverno/require-signed-images.yaml`](../lab-infra/supplychain/kyverno/require-signed-images.yaml):
```bash
kubectl apply -f lab-infra/supplychain/kyverno/require-signed-images.yaml
```
Try to run an **unsigned** image from Harbor: `kubectl -n oss500-demo run u --image=harbor.oss500.local/lib/unsigned:x --restart=Never` → **rejected by Kyverno** (`image is not signed` / failed attestor check).
Run the **signed** image: `kubectl -n oss500-demo run s --image=harbor.oss500.local/lib/alpine:3.20 --restart=Never` → **admitted**. Cluster-side gate proven, on top of Harbor's registry-side gate.

## Teardown
- `kubectl -n oss500-demo delete pod s u --ignore-not-found; kubectl delete clusterpolicy require-signed-images --ignore-not-found`
- `cd lab-infra/supplychain && ./down.sh`

## What the exam asks
- The gate is the **exit code** (`--exit-code 1` / `--fail-on`). `--ignore-unfixed` is a policy choice (don't fail on unactionable vulns); scan at build *and* continuously in the registry.
- Signing (cosign) proves **authenticity/integrity**, not vuln-freedom — a signed image can still be full of CVEs. You need scanning *and* signing.
- SBOM formats: **SPDX** and **CycloneDX**. An SBOM is an inventory; you scan it to get vulnerabilities.
- Two enforcement points: Harbor blocks the *pull* (severity threshold / signature policy); Kyverno `verifyImages` (cosign) blocks the *schedule*. The OSS Azure Policy for AKS + ACR content trust.
