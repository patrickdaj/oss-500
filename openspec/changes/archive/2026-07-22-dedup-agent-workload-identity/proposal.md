## Why

Domain 6 teaches the SPIFFE/SVID story twice within itself. `domains/6-agentic-zero-trust/d6-identity.md` (objective `agent-workload`, the section "Give the agent a workload identity separate from its delegated authority") and `domains/6-agentic-zero-trust/d6-multi-agent.md` (objective `agent-mtls`, the section "Authenticate agent-to-agent calls with SPIFFE mTLS, not network position") **both re-explain the same SVID mechanics**: short-lived and non-exportable, fetched from the SPIRE Workload API, mutual TLS with identity on both ends, "a co-located rogue can't obtain/impersonate a peer's SVID," and X.509-SVID (mTLS/proof-of-possession) vs JWT-SVID (bearer). Both notes correctly back-link the Domain 1 canonical note `domains/1-identity-governance/workload-identity.md` (`wi-spiffe`) — that reinforcement across domains is intentional and stays. The problem is the **two Domain 6 notes duplicating each other**: `d6-multi-agent` re-derives the SVID/mTLS primitive from scratch (lines ~13, 22, 27, 31, and the `agent-mtls` summary row) instead of leaning on the sibling that owns it.

The net-new idea in `d6-multi-agent`'s `agent-mtls` objective — the only part not already in `d6-identity` — is the **agent-to-agent authorization angle**: a callee authorizes a peer by its SPIFFE ID rather than by IP/subnet/"inside the mesh," and no privilege launders across the trust chain. That delta should stand alone; the SVID plumbing under it should be a reference, not a re-teach.

## What Changes

- **`d6-identity.md` becomes the single owner of the SVID re-explanation for Domain 6.** Its `agent-workload` section already carries the full story (short-lived/attested, Workload-API-fetched, X.509 vs JWT-SVID, per-principal SVIDs so agents can't impersonate each other) — no content change is required there beyond confirming it is the canonical Domain-6 anchor.
- **`d6-multi-agent.md`'s `agent-mtls` section is trimmed to the peer-authorization delta.** It keeps the net-new angle — authenticate/authorize a peer by SPIFFE ID not network position, mTLS applied *in the agent-to-agent context*, and the no-privilege-laundering framing — and **references `d6-identity` (`agent-workload`) for the SVID mechanics** instead of restating them. The Domain 1 (`wi-spiffe`) back-link is preserved.
- **No detail is lost.** Every mechanic removed from `d6-multi-agent` already lives in `d6-identity`; the trim replaces duplication with a cross-link, it does not delete coverage.
- **Spec:** the existing `agentic-zero-trust` requirement *"An agent has a distinct workload identity and a scoped delegated authority"* is MODIFIED to add a scenario asserting the SVID mechanics are taught once within Domain 6 (in `d6-identity`) and that `d6-multi-agent` references that canonical teaching, contributing only the agent-to-agent authorization delta. All existing scenarios are preserved verbatim.

## Capabilities

### Modified Capabilities
- `agentic-zero-trust`: the "distinct workload identity + scoped delegated authority" requirement gains a single-source-of-truth scenario for the SVID mechanics within Domain 6 (`d6-identity` canonical, `d6-multi-agent` references it). No requirement text is weakened; the existing scenarios are unchanged.

## Impact

- **Content:** `domains/6-agentic-zero-trust/d6-multi-agent.md` — the `agent-mtls` section (prose ~lines 13, 22; gotchas ~lines 27, 31; SVID resource link ~line 31; the `agent-mtls` summary-table row ~line 76) is trimmed to the peer-authorization delta and cross-links `d6-identity.md` (`agent-workload`) for the SVID/mTLS primitive. `domains/6-agentic-zero-trust/d6-identity.md` — confirmed canonical; no substantive edit expected.
- **No change to the Domain 1 back-links.** Both notes keep pointing at `workload-identity.md` (`wi-spiffe`); cross-domain reinforcement is intended and untouched.
- **Quiz overlap noted, handled elsewhere.** `assessment/data/quiz/quiz-6.yaml` questions `q6-01` and `q6-15` also probe overlapping SVID/mTLS ground; that quiz-level deduplication is out of scope here and is addressed by the separate `dedup-quiz-question-intent` change.
- **study-hub:** none — content-only; existing globs re-render the edited note.
- **Objective ids and labs:** unchanged. `agent-workload`, `agent-mtls`, `agent-cascade`, `agent-deleg` all keep their ids, labs, and cross-links; this is an editorial dedup, not a restructuring.
