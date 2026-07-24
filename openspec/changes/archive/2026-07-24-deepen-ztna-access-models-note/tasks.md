# Tasks — deepen-ztna-access-models-note

## 1. Write per-model subsections

- [x] 1.1 **Boundary** subsection: teach the scope → auth-method → host-catalog → host-set → target → role/grant chain the lab builds (front-loaded-Vault box style).
- [x] 1.2 **OpenZiti** subsection: identities, services, service/edge-router policies, and enrollment.
- [x] 1.3 **Pomerium** subsection: routes plus the policy schema binding an identity to a route.
- [x] 1.4 **NetBird** subsection: groups, setup-keys, and policies.

## 2. Rank references

- [x] 2.1 Mark each model's provider-registry doc as load-bearing (`required-for-lab`) per `rank-learning-references`; leave enrichment links as `[depth]`.

## 3. Validation

- [x] 3.1 Confirm each subsection names the objects and shows the minimal chain the corresponding `d1-*` ZTNA lab builds.
- [x] 3.2 Run `openspec validate deepen-ztna-access-models-note --type change --strict`.
