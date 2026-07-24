# Deepen the ZTNA access-models note into a real teaching note

## Why

`domains/1-identity-access/ztna-access-models.md` is a ~32-line lobby — a five-model table plus one PDP/PEP sentence — yet it is the **sole** "notes read" prerequisite for **four build-it-yourself Terraform labs** (Boundary+Vault, OpenZiti, Pomerium, NetBird), none of whose tool object models is taught anywhere (audit Part 4.3, line 118). Each lab quietly outsources its resource chain to vendor provider docs — the exact "which reference is load-bearing?" complaint this audit exists to fix. A learner authoring HCL against Boundary or OpenZiti for the first time has no course-side model of what objects he is even creating.

## What Changes

- Expand `ztna-access-models.md` with **per-model subsections**, each teaching the resource chain that model's lab actually builds:
  - **Boundary** — scope → auth-method → host-catalog → host-set → target → role/grant chain.
  - **OpenZiti** — identities, services, service/edge-router policies, and enrollment.
  - **Pomerium** — routes plus the policy schema binding an identity to a route.
  - **NetBird** — groups, setup-keys, and policies.
- Follow the house style already proven in the Boundary lab's front-loaded-Vault box (name the objects, show the minimal chain, then let the lab build it), and mark each model's provider-registry doc as load-bearing (per `rank-learning-references`) rather than one anonymous link.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `ztna-access-models` — adds a requirement that the access-models note teach each model's resource/object chain in-note, so the four Terraform labs no longer depend on untaught vendor object models as their only real source.

## Impact

- Affected specs: `ztna-access-models` (one ADDED requirement).
- Affected content (at implementation time): `domains/1-identity-access/ztna-access-models.md` gains four per-model subsections; each model's provider-registry doc is tagged load-bearing.
- Converts four "leave-the-curriculum, read the provider docs" labs into notes that teach what the learner is about to author.
