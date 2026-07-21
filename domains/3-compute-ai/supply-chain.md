# Secure the software supply chain and container images

Domain 3, subsection 3 (`d3-supplychain`). Everything running on the cluster arrived as a container image built from base layers, OS packages and application dependencies you mostly didn't write. Supply-chain security is about knowing what's *in* those images (scanning, SBOMs), controlling *where they come from* and *proving they're authentic* (private registry, signing), and *refusing to run* anything that fails those checks (admission gating). The tools: **Trivy** and **Grype** for vulnerability scanning, **Syft** for SBOMs, **Harbor** as a private registry with built-in scanning and signing policy, **cosign** (Sigstore) for signatures, and **Kyverno**/Harbor policy to gate admission.

Primary lab: [d3-supply-chain](../../labs/d3-supply-chain.md). Lab-infra component: [`lab-infra/supplychain`](../../lab-infra/supplychain/) (Harbor + Trivy + cosign; Trivy also runs as a CLI/Job, no cluster residency required). The SC-500 analogs are **Microsoft Defender vulnerability management** (image scanning in ACR/AKS), **Azure Container Registry** (private registry, content trust), and **Azure Policy for AKS** (admission gating on scan/signature).

## Scan images and dependencies for vulnerabilities

*Objective: `sc-scan` · OSS: Trivy / Grype ≈ SC-500: Defender vulnerability management · Lab: [d3-supply-chain](../../labs/d3-supply-chain.md)*

**Trivy** (Aqua Security) is the swiss-army scanner: it finds OS-package CVEs (Alpine/Debian/RHEL databases), language-dependency CVEs (npm, pip, Go modules, etc.), misconfigurations in IaC, exposed secrets, and it can produce SBOMs. **Grype** (Anchore) is a focused, fast image/filesystem vulnerability scanner that pairs with Syft. Both consume public vuln feeds and both exit non-zero on findings, which is what makes them CI gates rather than just reports.

```bash
# Trivy: fail the build if any CRITICAL vuln with a fix is present
trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 myapp:1.0

# Grype: scan the same image, gate on high+ severity
grype myapp:1.0 --fail-on high
```

`--exit-code 1` / `--fail-on` are the load-bearing flags — they turn a scan into a pass/fail control. `--ignore-unfixed` is the pragmatic tuning knob: don't fail a pipeline on a CRITICAL that has no vendor fix yet (you can't remediate it by rebuilding), while still failing on fixable ones. Trivy reads a `.trivyignore` (or VEX documents) to accept specific CVEs with a documented justification — the exceptions ledger the exam likes. You scan in **two places**: in CI on the freshly built image (shift-left, fail fast) *and* continuously in the registry (Harbor's built-in Trivy re-scans stored images as new CVEs are published, so an image that was clean at push becomes flagged later).

On SC-500 this is **Defender vulnerability management** for containers: it scans images in ACR at push and continuously, and scans running images in AKS, surfacing CVEs as recommendations feeding the secure score. Trivy/Grype in CI + Harbor's scanner is the same shift-left-plus-continuous model.

Exam gotchas:
- The gate is the exit code (`--exit-code 1` / `--fail-on high`). A scan with no failure threshold is a report, not a control.
- `--ignore-unfixed` changes *policy*, not detection — it hides vulns you can't act on yet; use it deliberately, and re-scan continuously so "no fix yet" becomes "fix available" without a rebuild.
- Scan at build time *and* in the registry over time. A CVE disclosed after push only shows up on a re-scan — point-in-time-only scanning is a classic gap.

**Resources:**
- [Trivy — Scanning](https://trivy.dev/latest/docs/target/container_image/) (~20 min)
- [Grype — Anchore Grype](https://github.com/anchore/grype) (~15 min)

## Secure a private registry and sign/verify images

*Objective: `sc-registry` · OSS: Harbor / cosign ≈ SC-500: Azure Container Registry · Lab: [d3-supply-chain](../../labs/d3-supply-chain.md)*

**Harbor** (CNCF) is a private OCI registry with the security features a bare registry lacks: RBAC per project, robot accounts for CI, a built-in **Trivy** scanner with per-project "prevent vulnerable images from running" thresholds, image **immutability** and **retention** rules, replication, and **cosign signature** verification policy. Running your own registry is itself a supply-chain control — you pull from a source you govern instead of directly from Docker Hub, and you can block anything unscanned or unsigned from being served.

**cosign** (Sigstore) signs and verifies images. It stores the signature as an OCI artifact alongside the image in the same registry, so no separate infrastructure. Keyed flow:

```bash
cosign generate-key-pair                          # -> cosign.key / cosign.pub
cosign sign --key cosign.key harbor.oss500.local/lib/myapp:1.0
cosign verify --key cosign.pub harbor.oss500.local/lib/myapp:1.0   # exits 0 only if signature valid
```

cosign also supports **keyless** signing (OIDC identity + the Fulcio CA + the Rekor transparency log) so there's no long-lived private key to protect — the signer's OIDC identity is bound into a short-lived cert and logged publicly. Beyond signatures, cosign **attaches attestations** (SBOMs, provenance/SLSA statements) as signed artifacts, so "this image + this SBOM + this build provenance" travels together and is verifiable. Harbor can be configured to **only serve signed images** (a cosign-backed content-trust policy on the project).

This is **Azure Container Registry** plus **ACR content trust / image signing**: a governed private registry with built-in scanning, RBAC/tokens, and signature enforcement. When a question mentions "sign images and verify them before deployment," the OSS stack is Harbor (registry) + cosign (signatures) + an admission check (`sc-admission`).

Exam gotchas:
- cosign stores the signature *in the registry as an OCI artifact* — verification needs the public key (keyed) or the OIDC identity + Rekor (keyless). Losing the private key breaks new signing, not existing verification.
- Signing proves *authenticity/integrity* (this image came from us, unmodified). It says nothing about *vulnerabilities* — a signed image can be full of CVEs. Scanning and signing are orthogonal; you need both.
- Harbor enforces at the registry (block vulnerable/unsigned from being pulled); an admission controller enforces at the cluster. Defense in depth uses both.

**Resources:**
- [Harbor — Documentation](https://goharbor.io/docs/) (~25 min)
- [cosign — Signing and verifying (Sigstore)](https://docs.sigstore.dev/cosign/signing/signing_with_containers/) (~20 min)

## Generate and evaluate SBOMs for deployed artifacts

*Objective: `sc-sbom` · OSS: Syft / Trivy SBOM ≈ SC-500: Supply-chain security · Lab: [d3-supply-chain](../../labs/d3-supply-chain.md)*

A **Software Bill of Materials (SBOM)** is a machine-readable inventory of everything in an artifact — every OS package and library with its version and license. It's the difference between "is Log4Shell in our fleet?" taking days of guessing versus one query against stored SBOMs. **Syft** (Anchore) generates SBOMs; **Trivy** can too. The two standard formats are **SPDX** and **CycloneDX** — know both names; tools and Azure both consume them.

```bash
syft harbor.oss500.local/lib/myapp:1.0 -o spdx-json > myapp.sbom.spdx.json
trivy image --format cyclonedx --output myapp.cdx.json myapp:1.0
# an SBOM feeds a scanner directly — scan the inventory, no image pull needed:
grype sbom:./myapp.sbom.spdx.json
```

The workflow that matters: **generate the SBOM at build time**, **sign/attach it to the image** (cosign attestation, above), and **re-scan the stored SBOM** whenever a new CVE lands — because you can answer "which artifacts contain package X at version Y" instantly, without re-pulling or rebuilding anything. That's the whole point of an SBOM as a security control: it converts an unknown ("what's in production?") into a queryable asset, and it's the substrate for post-hoc vulnerability response (Grype/Trivy scan an SBOM directly).

On SC-500 this is the **supply-chain security** / SBOM story around ACR and Defender — image inventory, provenance, and the ability to answer exposure questions across the estate. Syft/Trivy SBOMs + cosign attestations are the open-source implementation.

Exam gotchas:
- SBOM formats to recognize: **SPDX** and **CycloneDX**. A tool "produces an SBOM" — which format is often the distractor detail.
- An SBOM is an *inventory*, not a scan result. You scan the SBOM (Grype/Trivy) to get vulnerabilities. Generating an SBOM finds zero CVEs by itself.
- Attach the SBOM to the image as a signed attestation so inventory and provenance travel with the artifact and can't be swapped.

**Resources:**
- [Syft — Anchore Syft](https://github.com/anchore/syft) (~15 min)
- [Trivy — SBOM generation](https://trivy.dev/latest/docs/supply-chain/sbom/) (~15 min)

## Gate admission on scan results and signature verification

*Objective: `sc-admission` · OSS: Kyverno / Harbor policy ≈ SC-500: Azure Policy for AKS · Lab: [d3-supply-chain](../../labs/d3-supply-chain.md)*

Scanning and signing only protect you if something *refuses to run* what fails them. Two enforcement points: **Harbor** (registry-side) can block pulling images over a CVE-severity threshold or that lack a cosign signature; the **admission controller** (cluster-side) can reject any pod whose image isn't signed by a trusted key or doesn't come from the approved registry. Belt and suspenders — Harbor stops the bad image being served, Kyverno stops it being scheduled even if it got out.

Kyverno has first-class **image verification** that calls cosign under the hood:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-signed-images
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify-cosign-signature
      match:
        any:
          - resources: { kinds: ["Pod"] }
      verifyImages:
        - imageReferences:
            - "harbor.oss500.local/lib/*"     # only our registry, and only if signed
          attestors:
            - entries:
                - keys:
                    publicKeys: |-
                      -----BEGIN PUBLIC KEY-----
                      MFkwEwYHKoZI…               # the cosign.pub from sc-registry
                      -----END PUBLIC KEY-----
```

An unsigned or tampered image now fails admission with a clear message; a validly signed one is admitted. You can extend the same policy to require a **valid SBOM/vuln attestation** (verify an attestation exists and its scan passed a threshold) so admission gates on *scan result* as well as signature. The `imageReferences` restriction also enforces "images must come from `harbor.oss500.local`" — an allowlisted-registry control on its own.

This is **Azure Policy for AKS** doing image-integrity and allowed-registry enforcement — "Kubernetes cluster containers should only use allowed images", plus the ACR content-trust / signature-verification gate. The OSS-500 chain is complete here: build → scan (`sc-scan`) → SBOM (`sc-sbom`) → sign & store in Harbor (`sc-registry`) → **admission verifies signature/scan before scheduling** (`sc-admission`).

Exam gotchas:
- Registry policy (Harbor) and admission policy (Kyverno) are different enforcement points — one blocks the *pull*, the other blocks the *schedule*. Defense in depth wants both; exam scenarios sometimes ask specifically which one stops a given step.
- Kyverno `verifyImages` requires the public key (or keyless identity) — it's calling cosign verification at admission. `validationFailureAction: Enforce` makes it fail-closed.
- Gating on *signature* proves origin; gating on *attestation/scan result* proves it passed vuln policy. Requiring "signed AND scan-clean" needs both checks, not just a signature.

**Resources:**
- [Kyverno — Verify Images](https://kyverno.io/docs/writing-policies/verify-images/) (~25 min)
- [Harbor — Vulnerability scanning & deployment security](https://goharbor.io/docs/latest/administration/vulnerability-scanning/) (~15 min)

## Summary
| Objective | Takeaway |
|---|---|
| `sc-scan` | Trivy/Grype scan images for OS + dependency CVEs and gate CI via exit code; scan at build *and* continuously in the registry — the OSS Defender vuln management. |
| `sc-registry` | Harbor is a private OCI registry with RBAC, built-in scanning and signature policy; cosign signs/verifies images (keyed or keyless) — the OSS ACR + content trust. |
| `sc-sbom` | Syft/Trivy generate SPDX/CycloneDX SBOMs — a queryable inventory you scan and attach as a signed attestation to answer exposure questions instantly. |
| `sc-admission` | Kyverno `verifyImages` (cosign) and Harbor policy refuse unsigned/vulnerable/unapproved-registry images at schedule and pull time — the OSS Azure Policy for AKS. |
