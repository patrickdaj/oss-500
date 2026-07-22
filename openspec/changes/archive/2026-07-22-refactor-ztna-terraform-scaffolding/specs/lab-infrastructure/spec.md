## ADDED Requirements

### Requirement: Related lab-infra stacks share common scaffolding and the shared namespace scheme

A family of near-identical `lab-infra/` stacks (e.g. the ZTNA Terraform stacks `ztna-boundary`, `ztna-netbird`, `ztna-openziti`, `ztna-pomerium`) SHALL factor their shared scaffolding — the `up`/`down` bring-up/teardown flow, the tfvars-missing guard, and the common `versions`/`terraform.tfvars.example` boilerplate — into a single shared location rather than duplicating it per stack, WHILE keeping each stack's per-model `main.tf` in place, in full, as readable study material. In-cluster stacks in such a family SHALL join the shared PSA-labelled `oss500-*` namespace scheme in `lab-infra/shared/namespaces.yaml` rather than self-creating a bespoke namespace, or SHALL document inline why they opt out.

#### Scenario: Boilerplate is factored, per-model main.tf stays readable in place

- **WHEN** a reader opens any stack in a family of near-identical lab-infra stacks
- **THEN** the shared bring-up/teardown flow, tfvars guard, and common `versions`/`tfvars` boilerplate resolve to one shared definition (not copied into every stack), and that stack's own `main.tf` — the per-model Terraform the learner is meant to study — is still present in the stack directory, unchanged and readable without following an indirection

#### Scenario: A change to the shared scaffolding is made once

- **WHEN** the shared bring-up/teardown flow or the tfvars-missing guard for a stack family must change
- **THEN** the edit is made once in the shared location and takes effect for every stack in the family, rather than being repeated per stack

#### Scenario: In-cluster stacks use the shared PSA-labelled namespace scheme

- **WHEN** an in-cluster stack in the family is deployed (e.g. the Pomerium identity-aware proxy)
- **THEN** its resources land in an `oss500-*` namespace from `lab-infra/shared/namespaces.yaml` carrying `app.kubernetes.io/part-of: oss500` and a `pod-security.kubernetes.io/enforce` label, so a single `part-of=oss500` query returns them for teardown — or the stack documents inline why it opts out of the shared profile

#### Scenario: The refactor does not change what a stack teaches

- **WHEN** a stack's `main.tf`, objective ids, and deploy–verify–destroy observable are compared before and after the scaffolding is extracted
- **THEN** they are unchanged — only boilerplate was factored out, so the study value and the lab's coverage are preserved
