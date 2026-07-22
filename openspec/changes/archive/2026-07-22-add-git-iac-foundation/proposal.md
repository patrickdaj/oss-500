## Why

Phase 0 (Domain 0 fundamentals) grounds the learner in Linux, containers, Kubernetes, and networking — but the course leans hard on **git** and **Terraform** (the ZTNA labs are "all Terraform-automated"; `gov-iac` is an objective) with **no dedicated foundation** for either. `03-kind-helm-iac.md` gives only a Terraform *intro*, and there is no git note at all. A learner arriving without solid git + IaC fundamentals hits the automated labs under-prepared. This adds that groundwork.

## What Changes

- **New Phase 0 fundamentals note** `domains/0-fundamentals/05-git-iac-foundation.md`: a **git foundation** (the version-control model, commits/branches/remotes, the repo as the source of truth for infrastructure and GitOps) and a **Terraform foundation** (providers, **state** and locking, **modules**, the write → plan → apply workflow, remote state) — framed as the prerequisites the course's IaC/ZTNA labs assume. It cross-links `03-kind-helm-iac.md` (which it now underpins) and points forward to `gov-iac`.

## Capabilities

### New Capabilities
- `git-iac-foundation`: A Phase 0 fundamentals note establishing git and Terraform foundations as the groundwork for the course's IaC-automated labs and the `gov-iac` objective.

### Modified Capabilities
<!-- Domain 0 fundamentals are reading groundwork, not tracked objectives, so this adds
     a new capability rather than deltaing anything. No tracker/objective changes. -->
- None.

## Impact

- **Content (new)**: one note, `domains/0-fundamentals/05-git-iac-foundation.md`; a one-line cross-link added in `03-kind-helm-iac.md`. External links follow the `resource-citation` standard so `lint:links` stays green.
- **No tracker change**: Domain 0 fundamentals are not tracked as objectives (they're surfaced by living in `domains/0-fundamentals/`), so `tracker.yaml`, objective ids, and study-hub's domain/objective counts are unchanged — its tests stay green.
- **study-hub**: after the note lands, bump the `content/oss-500` submodule and confirm `lint:content` + tests pass and the note renders as Phase 0 reading.
