# lab-infra/ztna-common — shared scaffolding for the ZTNA stack family

The four ZTNA reference solutions — [`../ztna-boundary`](../ztna-boundary), [`../ztna-netbird`](../ztna-netbird), [`../ztna-openziti`](../ztna-openziti), [`../ztna-pomerium`](../ztna-pomerium) — are a **family**: each demonstrates a different zero-trust access model, but each wraps one genuinely per-model `main.tf` in the same scaffolding. This directory single-sources that scaffolding so a change to it is made **once, not four times**.

## What lives here

- **[`tf.sh`](tf.sh)** — the invariant bring-up/teardown flow: `set -euo pipefail`, the tfvars-missing guard, and `terraform init` / `apply` / `destroy` (all `-input=false -auto-approve`). Each stack's `up.sh`/`down.sh` is a thin caller that `cd`s to its own dir, prints its per-model header + verify hint, and invokes `../ztna-common/tf.sh up|down`.
- **[`versions.tf.tmpl`](versions.tf.tmpl)** — the common `terraform { required_version = ">= 1.6" ... }` shape. Provider-specific `required_providers`/`provider` blocks deliberately stay in each stack's `versions.tf` so no shared file has to know every provider.
- **[`terraform.tfvars.example`](terraform.tfvars.example)** — the shared tfvars preamble each stack's example opens with.

## What deliberately does NOT live here

**Each stack's `main.tf`.** The per-model Terraform a learner is meant to read stays in full in its own `ztna-*/` directory, unchanged. `tf.sh` never reads or rewrites it — it only runs `terraform` in the caller's directory. Open any `ztna-*/main.tf` and you see the whole per-model stack without following an include. Only invariant plumbing is factored out here, never per-model logic.
