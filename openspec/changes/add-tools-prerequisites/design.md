# Design — add-tools-prerequisites

## TOOLS.md shape

A single table, ordered by the phase a tool first appears, so it doubles as an install checklist:

| Tool | First used | Install (macOS) | Install (Linux) | Notes |
|---|---|---|---|---|
| jq | Phase 2 (Vault up.sh) | `brew install jq` | `apt-get install jq` | parses Vault init JSON |
| terraform | Phase 1 Day 6 | `brew install hashicorp/tap/terraform` | see HashiCorp apt repo | ZTNA labs are TF-automated |
| vault / boundary | Phase 1–2 | `brew install hashicorp/tap/<t>` | HashiCorp apt repo | |
| ziti, ziti-edge-tunnel | Phase 1 Day 6 | GitHub releases (openziti) | GitHub releases | two separate binaries |
| netbird | Phase 1 Day 6 | `brew install netbirdio/tap/netbird` | install.netbird.io | |
| tsh, tctl | Phase 1 Day 4 | Teleport install page | Teleport install page | already linked in the PAM lab |
| cmctl | Phase 2 Day 4 | `brew install cmctl` | GitHub releases | |
| istioctl | Phase 2 Day 5 | `istioctl` install / printed by up-mesh.sh | same | |
| cilium, hubble | Phase 2 Day 7 | cilium-cli GitHub releases | same | |
| trivy, grype, syft, cosign | Phase 2–3 | `brew install trivy grype syft cosign` | GitHub releases | |
| gitleaks | Phase 2 Day 6 | `brew install gitleaks` | GitHub releases | |
| opa | Phase 3 Day 5 | `brew install opa` | GitHub releases | |
| kubescape, kube-bench | Phase 1/4 | curl installers | curl installers | already in governance/posture READMEs |
| sigma (sigma-cli) | Phase 4 Day 4 | `pipx install sigma-cli` | `pipx install sigma-cli` | |
| garak, pyrit | Phase 5 | `pipx run garak` / `pip install pyrit` | same | Python-based |
| caldera, stratus, atomic | Phase 5 | git clone / GitHub releases | same | see offense README |
| psql (libpq) | Phase 2 Day 2 | `brew install libpq` (keg-only) | `apt-get install postgresql-client` | or `exec` the postgres/psql-client pod |

The exact per-tool commands are filled in at implementation; the table above is the agreed structure.

## Per-lab convention

Each lab's existing **Prerequisites** bullet list gains (where it invokes non-baseline CLIs) a line:

```markdown
- Tools for this lab: `vault`, `boundary`, `terraform` — see [`TOOLS.md`](../TOOLS.md).
```

Labs that already point at installs (Teleport PAM, supply-chain, governance) just add the `TOOLS.md` cross-link for consistency; labs missing pointers (ZTNA, AI `opa`, cert `cmctl`, data-protection `trivy`/`gitleaks`) get the full line.

## Scope decision

- Baseline four (Docker/kind/kubectl/Helm) remain the only *day-one* installs; the point is not "install 25 tools now" but "each tool has a documented source at the moment you need it."
- Terraform and `jq` are the two promoted to the top-level prerequisite lists because they're load-bearing early and their absence hard-fails a script (`tf.sh`, `secrets/up.sh`).
- A CI check that greps labs for invoked binaries and asserts each appears in `TOOLS.md` is a nice-to-have, noted as a follow-up, not required here.

## Alternatives considered

- **Auto-install everything in `up.sh` scripts** — rejected: opaque, fights the "reading the manifests is study" ethos, and mixes host-tool installs into per-component bring-up.
- **Per-lab install commands only (no central page)** — rejected: duplicates install text across labs and gives no single checklist; the central `TOOLS.md` + a per-lab cross-link is DRY.
