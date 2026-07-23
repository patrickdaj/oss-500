# Make Phase 6 SPIRE honest: stop claiming a server that was never deployed

## Why

Phase 6 (agentic zero trust) reuses the workload-identity story on an agent, and its labs/notes tell the learner to use a **running SPIRE server** — but no SPIRE server is ever deployed, and the docs contradict each other about it.

- `lab-infra/identity` deploys only Keycloak + PostgreSQL (there are zero `spire` references in `lab-infra/` outside `agentic/`), yet the **first step of the first Phase-6 lab** is `kubectl -n oss500-identity exec deploy/spire-server -- …` (`labs/d6-identity.md:15,27`), which dead-ends with `deployments.apps "spire-server" not found`. `domains/6-agentic-zero-trust/d6-identity.md` and `labs/d6-multi-agent.md` similarly describe SPIRE as "reused from Domain 1."
- Domain 1 covered SPIFFE/SPIRE **as a walkthrough only** — no server ever ran — so there is nothing to reuse.
- Meanwhile the infra docs are honest: `lab-infra/agentic/README.md`/`up.sh` and `lab-infra/agentic/spire/registration.md` say SPIRE is **not** deployed and must be stood up by hand. But `registration.md` is a hand-wave — its only concrete command (`spire-server entry create`) presupposes a fully configured server + agent, the `oss500.local` trust domain, k8s PSAT attestation, a `spire-agent` daemonset, and the Workload API socket mounted into pods — none of which is provided or stepped through.

Net effect for this persona (never operated SPIRE): a "reused from Domain 1" command that `NotFound`s reads as "my earlier setup is broken," triggering a debugging goose-chase; and the honest-but-incomplete `registration.md` is a multi-hour yak-shave with no followable path. The `agent-workload` and `agent-mtls` proofs are presented as *runnable*, so the learner thinks they must reach them.

## What Changes

Make the SPIRE story internally consistent and honest. Two acceptable resolutions; pick one in `design`:

- **(A) Ship a real, minimal SPIRE** under `lab-infra/agentic/spire/` (Helm values or manifests for a SPIRE server + `spire-agent` daemonset, `oss500.local` trust domain, k8s PSAT node/workload attestation, Workload API socket wiring), so the `agent-workload`/`agent-mtls` observables are genuinely reproducible; then keep them as run-it proofs. **or**
- **(B) Re-label the SVID-issuance parts of `agent-workload`/`agent-mtls` as walkthrough/directions** (exactly as federation and the MCP-over-HTTP transport already are), remove every "already running / reused from Domain 1" claim and the `exec deploy/spire-server` step, and make `registration.md` an honest "here's the shape; standing up SPIRE is out of scope for the run-it path" note.

Either way: no lab step may `exec` into a `spire-server` that no component deploys, and the labs/notes must match the plan's framing.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agentic-zero-trust` — adds a requirement that the agent workload-identity (SPIRE) steps are either backed by a deployed SPIRE or clearly marked directions-only, with no lab claiming a SPIRE server that is not deployed.

## Impact

- Affected specs: `agentic-zero-trust` (one ADDED requirement).
- Affected content (at implementation time): `labs/d6-identity.md`, `labs/d6-multi-agent.md`, `domains/6-agentic-zero-trust/d6-identity.md`, `lab-infra/agentic/spire/registration.md`, and (if option A) new SPIRE manifests + `up.sh` wiring.
- Removes the biggest "is my earlier setup broken?" trap in the course.
