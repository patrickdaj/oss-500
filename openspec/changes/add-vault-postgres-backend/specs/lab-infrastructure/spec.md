## ADDED Requirements

### Requirement: A lab's prove-it observable is reproducible from the shipped component
Every backend, service, credential, or client that a lab's verification step depends on SHALL be created by that lab's backing `lab-infra/` component `up.sh` (or by the lab's own explicit steps) — never assumed to exist. A lab SHALL NOT reference a manifest, host, or namespace that the component does not actually provide.

#### Scenario: The dynamic-secrets lab has its database backend
- **WHEN** a learner runs `lab-infra/secrets/up.sh` and follows `labs/d2-vault-dynamic-secrets.md` Part C
- **THEN** a Postgres Deployment and Service exist at the host the lab names, and a psql-capable client is available, so `vault write database/config/appdb` connects and the dynamic credential can be tested

#### Scenario: Lease revocation is observable end to end
- **WHEN** the learner reads a dynamic credential, uses it against Postgres, then revokes the lease (or waits for TTL expiry)
- **THEN** the credential is accepted before revocation and rejected after — the `vault-dynamic` observable — rather than failing at `vault write database/config` because no database exists

#### Scenario: No dangling references to absent resources
- **WHEN** the lab or the component's scripts name a manifest, host, or namespace (e.g. `postgres.oss500-secrets`)
- **THEN** that resource is actually created by the component and the scripts and lab agree on one name (no `postgres.yaml` that does not exist, no namespace mismatch between `configure.sh` and the lab)
