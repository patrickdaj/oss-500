# Central tools manifest + per-lab tool prerequisites

## Why

The persona audit found a systemic "where do I get this?" gap. The top-level `README.md` and `lab-infra/README.md` list prerequisites as only **Docker, kind, kubectl, Helm** (+ git), but across `labs/*.md` the commands invoke roughly two dozen more CLIs: `terraform, vault, boundary, ziti, ziti-edge-tunnel, netbird, tsh, tctl, cmctl, istioctl, cilium, hubble, trivy, grype, syft, cosign, gitleaks, opa, kubescape, kube-bench, sigma, garak, pyrit, caldera, stratus, psql`, and now **`jq`** (the reworked `lab-infra/secrets/up.sh` requires it to parse Vault's init output).

There is **no central "install-as-you-go" tools page** and **no per-lab tool-prerequisite convention** — install pointers are ad hoc (the Teleport, supply-chain, and governance labs link/echo installs well; the ZTNA, AI-`opa`, cert-`cmctl`, and data-protection `trivy`/`gitleaks` labs don't). Terraform is the sharpest case: the `ztna-common/tf.sh` wrapper runs `terraform init/apply` and simply dies if it's absent, yet Terraform is never listed as a prerequisite — its install link is buried in a fundamentals "primary sources" list. The result is repeated `command not found` papercuts, worst when the install method is non-obvious (`boundary`, `ziti`'s two binaries, `garak`/`pyrit` via pipx), which is exactly the time-sink the course is meant to avoid.

## What Changes

- Add a **central `TOOLS.md`** (repo root, linked from both READMEs): a matrix of every CLI the labs use → the phase it first appears → a one-line install per OS (macOS/brew + Linux), grouped so a learner installs each tool just-in-time rather than all at once. Baseline four (Docker/kind/kubectl/Helm) stay the day-one prerequisites; everything else is "installed as its phase arrives."
- **Promote Terraform and `jq` to first-class listed prerequisites** in `README.md` and `lab-infra/README.md` (Terraform is required from Phase 1 Day 6; `jq` from the Vault bring-up), with install links.
- Establish a lightweight **per-lab tool-prerequisite convention**: each lab's Prerequisites block names the non-baseline CLIs it invokes and links `TOOLS.md` (or the tool's install page). Back-fill the labs currently missing pointers (ZTNA brokers, AI `opa`, cert `cmctl`, data-protection `trivy`/`gitleaks`).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `lab-infrastructure` — adds a requirement that every CLI a lab invokes has a documented install source (a central tools manifest + per-lab tool prerequisites), so no lab step fails on an un-obtained, unpointed binary.

## Impact

- Affected specs: `lab-infrastructure` (one ADDED requirement).
- Affected content (at implementation time): new `TOOLS.md`; edits to `README.md` and `lab-infra/README.md` (prereq lists + link); per-lab Prerequisites blocks in the labs currently missing tool pointers.
- Directly addresses Category C of the persona walkthrough audit; pairs with the seven applied blocker fixes (several of which introduced or depend on these CLIs).
