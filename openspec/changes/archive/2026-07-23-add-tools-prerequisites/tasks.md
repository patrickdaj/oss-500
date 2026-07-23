# Tasks — add-tools-prerequisites

## 1. Central tools manifest

- [x] 1.1 Create `TOOLS.md` at the repo root: a table of every CLI the labs invoke → phase first used → install per OS (macOS/brew + Linux), ordered by phase (per `design.md`). Enumerate from a grep of `labs/*.md` so nothing is missed.
- [x] 1.2 Verify coverage: `grep` the labs for invoked binaries and confirm each appears in `TOOLS.md` (the ~25: terraform, vault, boundary, ziti, ziti-edge-tunnel, netbird, tsh, tctl, cmctl, istioctl, cilium, hubble, trivy, grype, syft, cosign, gitleaks, opa, kubescape, kube-bench, sigma, garak, pyrit, caldera, stratus, psql, jq).

## 2. Promote Terraform + jq; link TOOLS.md

- [x] 2.1 Add **Terraform** and **`jq`** to the prerequisite/software lists in `README.md` and `lab-infra/README.md`, with install links, and link `TOOLS.md` from both as "install the rest as each phase arrives."
- [x] 2.2 Keep Docker/kind/kubectl/Helm as the day-one baseline; frame the others as just-in-time.

## 3. Per-lab tool prerequisites

- [x] 3.1 Add a "Tools for this lab: `<clis>` — see [`TOOLS.md`]" line to the Prerequisites block of each lab that invokes non-baseline CLIs, prioritising the ones currently missing pointers: the four `d1-ztna-*` labs (terraform/vault/boundary/ziti/netbird), `d3-ai-security` (`opa`), `d2-cert-manager` (`cmctl`), `d2-data-protection` (`trivy`/`gitleaks`).
- [x] 3.2 For labs that already link installs (Teleport PAM, supply-chain, governance/posture), add the `TOOLS.md` cross-link for consistency.

## 4. Validation

- [x] 4.1 Coverage check from 1.2 passes (every invoked CLI is in `TOOLS.md`).
- [x] 4.2 `npm run lint:links` OK (TOOLS.md links resolve; no generic-link lint failures in `labs/**`).
- [x] 4.3 `npx openspec validate add-tools-prerequisites --strict` passes.
- [ ] 4.4 (follow-up, optional) A CI grep asserting labs↔TOOLS.md coverage stays in sync.
