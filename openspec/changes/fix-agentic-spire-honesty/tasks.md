# Tasks — fix-agentic-spire-honesty

## 1. Decide the resolution (design)

- [ ] 1.1 Choose (A) ship a real minimal SPIRE under `lab-infra/agentic/spire/`, or (B) re-label the SVID proofs as walkthrough/directions. Record the choice.

## 2. Remove the false "already running" claims (both options)

- [ ] 2.1 In `labs/d6-identity.md`, remove/replace the `kubectl -n oss500-identity exec deploy/spire-server …` step and any "reused from Domain 1 / already running" SPIRE wording.
- [ ] 2.2 Do the same in `labs/d6-multi-agent.md` and `domains/6-agentic-zero-trust/d6-identity.md`.

## 3a. Option A — ship SPIRE

- [ ] 3a.1 Add SPIRE server + `spire-agent` daemonset manifests/Helm values under `lab-infra/agentic/spire/` (trust domain `oss500.local`, k8s PSAT attestation, Workload API socket mounted into agent pods).
- [ ] 3a.2 Wire `lab-infra/agentic/up.sh` to deploy it and rewrite `registration.md` into followable, run-it steps.

## 3b. Option B — mark as walkthrough

- [ ] 3b.1 Re-label the SVID-issuance parts of `agent-workload`/`agent-mtls` as walkthrough/directions (consistent with federation + MCP-over-HTTP), so the learner knows the running proof is optional.
- [ ] 3b.2 Rewrite `lab-infra/agentic/spire/registration.md` as an honest "here is the shape; standing up SPIRE is out of scope for the run-it path" note; keep the Keycloak token-exchange plane as the run-it identity story.

## 4. Validation

- [ ] 4.1 `cd lab-infra/agentic && ./up.sh` and walk `labs/d6-identity.md` step 1: no command references a `spire-server` that is not deployed; nothing `NotFound`s.
- [ ] 4.2 Confirm every remaining "run it" SPIRE step actually works (option A) or is clearly marked directions-only (option B); confirm labs/notes match `plan/phase6-agentic-zero-trust.md`.
- [ ] 4.3 Run `npm run lint:links` and `npx openspec validate fix-agentic-spire-honesty --strict`.
