## Why

The four ZTNA Terraform stacks — `lab-infra/ztna-boundary/`, `lab-infra/ztna-netbird/`, `lab-infra/ztna-openziti/`, `lab-infra/ztna-pomerium/` — are a family of near-identical stacks that each re-ship the same scaffolding around one genuinely per-model file (`main.tf`):

- **`up.sh`** — every stack repeats the same shebang, `set -euo pipefail`, `cd "$(dirname "$0")"`, the identical tfvars-missing guard (`if [ ! -f terraform.tfvars ]; then echo "Copy terraform.tfvars.example -> terraform.tfvars and fill it in first." >&2; exit 1; fi`), and the same `terraform init -input=false` / `terraform apply -input=false -auto-approve` pair. Only the header comment and the post-apply "how to verify" hint are per-model.
- **`down.sh`** — identical `set -euo pipefail`, `cd`, and `terraform destroy -input=false -auto-approve`. Only a trailing echo (and OpenZiti's `rm -f host.jwt client.jwt`) differs.
- **`versions.tf`** — the same `terraform { required_version = ">= 1.6" ... }` block shape plus a `provider` block that differs only in provider name/source/credentials.
- **`variables.tf`**, **`terraform.tfvars.example`**, and the README preamble repeat the same boilerplate framing.

Only each stack's `main.tf` is genuinely per-model — and per the `lab-infrastructure` and `guided-lab-pedagogy` specs, that `main.tf` is study material a learner is meant to read in place. This is maintenance-surface duplication: a change to the guard or the init/apply flags must be made four times and will drift.

Separately, a consistency nit: `lab-infra/ztna-pomerium/main.tf` sets `create_namespace = true` for its own `ztna-pomerium` namespace, bypassing the shared, PSA-labelled `oss500-*` namespace scheme in `lab-infra/shared/namespaces.yaml` that every other in-cluster stack uses. That is the one ZTNA stack that runs in-cluster, and it is the only one skipping the project's namespace/labeling and Pod Security Admission convention (the `oss500-*` namespaces carry `app.kubernetes.io/part-of: oss500` and `pod-security.kubernetes.io/enforce`), which the "everything is labeled" guardrail requires.

## What Changes

- **Extract the shared ZTNA scaffolding** into a new common location (`lab-infra/ztna-common/`): a shared `up`/`down` wrapper that carries the `set -euo pipefail`, tfvars-missing guard, and `terraform init`/`apply`/`destroy` flow, plus a shared `versions.tf`/`terraform.tfvars.example` template for the common bits. Each stack's `up.sh`/`down.sh` becomes a thin caller that supplies only its per-model header and post-apply hint.
- **Keep each stack's `main.tf` in place, unchanged and readable** — the per-model Terraform a learner studies is explicitly NOT hidden or centralized. Only boilerplate is factored out.
- **Land Pomerium in the shared PSA namespace scheme**: add an `oss500-ztna` namespace (PSA-labelled) to `lab-infra/shared/namespaces.yaml`, point `ztna-pomerium/main.tf` at it with `create_namespace = false`, and if any opt-out remains, document why in the stack README.
- **Add a `lab-infrastructure` requirement** codifying that families of near-identical stacks factor boilerplate into a shared location while keeping per-stack `main.tf` as readable study material, and that in-cluster stacks use the shared PSA-labelled namespace scheme.

## Capabilities

### Modified Capabilities

- `lab-infrastructure`: ADD a requirement that related lab-infra stacks share common scaffolding (up/down/versions/tfvars) while keeping each stack's `main.tf` as in-place study material, and that in-cluster stacks join the shared PSA-labelled namespace scheme. (No existing requirement is modified; the "Shared building blocks are reused", "Everything is labeled", and "Infrastructure code doubles as study material" requirements are reinforced, not changed.)

## Impact

- `lab-infra/ztna-boundary/`, `lab-infra/ztna-netbird/`, `lab-infra/ztna-openziti/`, `lab-infra/ztna-pomerium/` — `up.sh`/`down.sh` reduced to thin callers of the shared wrapper; duplicated `versions.tf`/`terraform.tfvars.example` boilerplate repointed to the shared template. Each stack's `main.tf` is untouched and stays in place.
- `lab-infra/ztna-common/` (new) — shared `up`/`down` wrapper and shared `versions`/`tfvars` template; a short README explaining the family pattern and that per-model logic lives in each stack's `main.tf`.
- `lab-infra/ztna-pomerium/main.tf` — namespace switched to the shared `oss500-ztna` namespace with `create_namespace = false` (no longer self-creates `ztna-pomerium`).
- `lab-infra/shared/namespaces.yaml` — gains an `oss500-ztna` namespace carrying `app.kubernetes.io/part-of: oss500` and a `pod-security.kubernetes.io/enforce` label.
- `openspec/specs/lab-infrastructure/spec.md` — gains one ADDED requirement (via delta).
- No change to what any ZTNA lab teaches: objective ids, mappings, the per-model `main.tf` contents, and the deploy–verify–destroy observables are unchanged.
