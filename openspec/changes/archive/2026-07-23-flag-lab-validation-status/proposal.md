# Disclose per-lab validation status (what's host-validated vs. pending)

## Why

OSS-500 is a freshly authored curriculum. Its labs are written to be correct and their `lab-infra` is real, but **most lab observables have not yet been run end-to-end on a real host by the author** — and a learner has no way to tell which steps are battle-tested and which are freshly built. That is a trust and time-management gap: if a step doesn't behave as written, the learner can't distinguish "I made a mistake" from "this hasn't been shaken out yet," which is exactly the wild-goose-chase the course tries to avoid.

The recent lab-blocker fixes make this concrete. Several were verified only as far as a laptop without a running kind cluster allows, with the last-mile runtime confirmation explicitly deferred to a host run (recorded as host-pending tasks in the archived changes):

- `labs/d2-vault-dynamic-secrets.md` — the dynamic-secrets flow is verified end to end, but the **Raft init/unseal bring-up** on kind is not.
- `labs/d3-ai-security.md` / `labs/d5-ai-redteam.md` — the gateway's authn/OPA/rate-limit are verified, but the **NeMo Guardrails rails + model round-trip** on kind is not.
- `labs/d6-identity.md` / `labs/d6-multi-agent.md` — the SPIRE manifests/wiring are correct, but the **SPIRE chart bring-up + SVID issuance** on kind is not.
- `labs/d1-ztna-boundary.md` — the Vault SSH-CA setup is verified, but the full **`boundary connect` injection** against a CA-trusting target is not.
- `labs/d4-siem-wazuh.md` — the agent-network fix mechanism is verified, but **full Wazuh agent enrollment** is not.

A learner deserves to know this up front — both for the course as a whole and at the specific steps most likely to need shaking out.

## What Changes

- Add a **course-level validation-status disclosure** (in `labs/README.md`) stating plainly that the curriculum is newly authored, that `lab-infra` is real and reviewable, and that some lab observables are pending an author host-run — so learners calibrate expectations and treat a stuck step as a *finding to report*, not a personal failing (the same honesty ethic Domain 5 teaches).
- Establish a lightweight, consistent **per-lab "Validation status" marker** as a course convention (`guided-lab-pedagogy`): a one-line note near the lab's Verification/observable that states whether the observable is author-host-validated or **host-pending**, with a pointer to what specifically hasn't been run.
- Apply the **host-pending** marker to the labs whose runtime observables were deferred by the recent fixes (the five above), naming the exact step. Labs whose observables *have* been validated may carry the positive marker, but this change does not require back-filling every lab — it requires the honest disclosure and the marker on the known-pending ones.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `guided-lab-pedagogy` — adds a requirement that a lab discloses whether its prove-it observable has been validated on a host, so a learner can tell a freshly-built step from a shaken-out one.

## Impact

- Affected specs: `guided-lab-pedagogy` (one ADDED requirement).
- Affected content (at implementation time): `labs/README.md` (course-level disclosure) and a "Validation status" line in `labs/d1-ztna-boundary.md`, `d2-vault-dynamic-secrets.md`, `d3-ai-security.md`, `d4-siem-wazuh.md`, `d5-ai-redteam.md`, `d6-identity.md`, `d6-multi-agent.md`.
- No behavioral/tooling change; this is honesty-of-status metadata that reduces wild-goose-chases.
