## Context

`lab-infra/` provisions the OSS-500 lab stack as code, and per the `lab-infrastructure` spec the IaC "doubles as study material" — reading a stack's Terraform is itself study. The four ZTNA stacks (`ztna-boundary`, `ztna-netbird`, `ztna-openziti`, `ztna-pomerium`) are a family: each demonstrates a different zero-trust access model, but each ships the same scaffolding around one genuinely per-model `main.tf`.

Confirmed by reading the four stacks:

- All four `up.sh` share the identical shebang, `set -euo pipefail`, `cd "$(dirname "$0")"`, tfvars-missing guard, and `terraform init -input=false` + `terraform apply -input=false -auto-approve`. Only the header comment and the trailing "verify like this" hint are per-model.
- All four `down.sh` share `set -euo pipefail`, `cd`, and `terraform destroy -input=false -auto-approve`; only a trailing echo and OpenZiti's `rm -f host.jwt client.jwt` differ.
- All four `versions.tf` share the `required_version = ">= 1.6"` block; the `required_providers`/`provider` blocks differ only by provider (boundary / netbird / ziti / helm) and credentials wiring.
- `variables.tf`, `terraform.tfvars.example`, and the README preamble repeat the same framing.

Only each `main.tf` is genuinely per-model. Separately, `ztna-pomerium/main.tf` (the one in-cluster ZTNA stack) sets `create_namespace = true` for a bespoke `ztna-pomerium` namespace, skipping the shared `oss500-*` PSA-labelled scheme in `lab-infra/shared/namespaces.yaml` that every other in-cluster stack uses.

## Goals / Non-Goals

**Goals**

- Single-source the ZTNA scaffolding (up/down flow, tfvars guard, common `versions`/`tfvars` template) so a change to it is made once, not four times.
- Bring the Pomerium stack into the shared `oss500-*` PSA-labelled namespace scheme so all lab resources are uniformly labelled for teardown and carry a Pod Security Admission profile.
- Codify the pattern as a `lab-infrastructure` requirement so future stack families inherit it.

**Non-Goals**

- **Do NOT obscure the per-model `main.tf` study value.** The Terraform a learner is meant to read stays in each stack directory, in full, unchanged. No centralizing `main.tf`, no macro/templating layer over it, no indirection that forces a reader to jump elsewhere to understand what a stack builds.
- **Do NOT change what any ZTNA lab teaches.** Objective ids, SC-500 mappings, provider choices, resource shapes, and the deploy–verify–destroy observables are invariant. This is a refactor of boilerplate, not of pedagogy.
- Do not touch the non-ZTNA stacks or the shared cluster/ingress bring-up beyond adding the one namespace.

## Decisions

**Shared wrapper shape.** Add `lab-infra/ztna-common/` holding a wrapper (e.g. `apply.sh`/`destroy.sh` or a single `tf.sh <up|down>`) that carries the invariant flow: `set -euo pipefail`, the tfvars-missing guard, and `terraform init -input=false` / `terraform apply -input=false -auto-approve` / `terraform destroy -input=false -auto-approve`. Each stack's `up.sh`/`down.sh` becomes a thin caller that `cd`s to its own dir, prints its per-model header/verify hint, and invokes the shared wrapper. Per-model tails (OpenZiti's `rm -f *.jwt`) stay in that stack's own script. A shared `versions.tf` fragment / `terraform.tfvars.example` template covers only the common bits; provider-specific `required_providers` stay per stack.

**How `main.tf` stays visible.** `main.tf` is deliberately excluded from the extraction. It remains a first-class file in each `ztna-*/` directory, with its existing SC-500-annotated comments intact. The shared wrapper never reads or rewrites it — it only runs `terraform` in the stack's directory. A reader opening any `ztna-*/` still sees the full per-model Terraform without following an include.

**Pomerium namespace decision.** Add an `oss500-ztna` namespace to `lab-infra/shared/namespaces.yaml` carrying `app.kubernetes.io/part-of: oss500` and a `pod-security.kubernetes.io/enforce` label (restricted where the workload tolerates it, else baseline with a comment explaining why — Pomerium's proxy pods may need a relaxed profile; pick the tightest that runs and annotate it). Change `ztna-pomerium/main.tf` to target `oss500-ztna` with `create_namespace = false`, matching every other in-cluster stack. If Pomerium genuinely cannot run under the shared profile, keep it in `oss500-ztna` but document the PSA exception inline (the `oss500-security` namespace is the existing precedent for a documented privileged exception).

## Risks / Trade-offs

- **Over-abstraction hurting readability.** Factoring scripts into a shared wrapper risks the "what does `up.sh` actually run?" indirection that the study-material mandate warns against. *Mitigation:* keep each stack's `main.tf` in place and unchanged (the actual study surface), keep the wrapper tiny and readable, and keep each stack's `up.sh` header/verify hint local so the per-model narrative is still read in the stack directory. The wrapper hides only invariant plumbing, never per-model logic.
- **Namespace/PSA change could break the Pomerium bring-up.** Moving Pomerium under a PSA-enforced namespace may trip on securityContext requirements. *Mitigation:* choose the tightest PSA profile that the chart runs under and document any relaxation inline, mirroring the `oss500-security` precedent; verify `up`/`down` before landing.
- **Provider-specific bits leaking into the shared template.** Keeping `required_providers` per stack (not in the shared fragment) avoids a shared file that must know every provider — the trade-off is a small amount of remaining per-stack `versions.tf`, which is acceptable and correct.
