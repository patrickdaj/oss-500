## Context

Domain 6 (`agentic-zero-trust`, beyond-blueprint) extends the zero-trust identity thread onto a new principal — the agent. Two of its subsection notes touch SPIFFE/SVID:

- `d6-identity.md` — objective `agent-workload`. Its whole reason to exist is to separate an agent's **workload identity** (a SPIRE-issued SVID: *who the process is*) from its **delegated authority** (an RFC 8693 on-behalf-of token: *what it may do for which user*). The SVID mechanics — short-lived, attested, fetched just-in-time from the Workload API, never stored, X.509-SVID for proof-of-possession mTLS vs JWT-SVID bearer, one distinct SVID per agent principal — are taught in full here (note lines ~13, 27, 30–33).
- `d6-multi-agent.md` — objective `agent-mtls`. Its reason to exist is agent-to-agent trust: how callee B decides caller A *is* A (**identity, not network position**) and why a compromised A cannot launder privilege through B. But its prose (lines ~13, 22) and gotchas (lines ~27, 31), plus its resource link and summary row (lines ~31, 76), re-derive the same SVID/mTLS primitive `d6-identity` already owns: "short-lived, non-exportable X.509 identity document it fetches from the SPIRE Workload API," "minted and rotated by SPIRE … a co-located process cannot obtain agent-a's SVID," "the agent never holds long-lived key material."

Both notes also back-link the Domain 1 canonical `workload-identity.md` (`wi-spiffe`). That cross-domain reinforcement is a feature — it is how Domain 6 shows the agent is "just a new kind of workload." The duplication that this change targets is strictly the **intra-Domain-6** one: two sibling notes re-teaching the same primitive to each other's readers.

This is a proposal-only change (author the artifacts; do not edit the course notes). It is authored alongside the sibling `dedup-quiz-question-intent` change, which handles the parallel overlap in `quiz-6.yaml` (`q6-01` / `q6-15`).

## Goals / Non-Goals

**Goals:**
- Make `d6-identity` (`agent-workload`) the single Domain-6 owner of the SVID re-explanation.
- Reduce `d6-multi-agent`'s `agent-mtls` section to its net-new contribution: peer authorization by SPIFFE ID vs IP, mTLS *applied in the agent-to-agent context*, and no privilege laundering across the chain — with a reference to `d6-identity` for the primitive itself.
- Preserve every existing spec scenario; only add one.

**Non-Goals:**
- **Do not weaken the Domain 1 back-links.** Both notes keep pointing at `workload-identity.md` (`wi-spiffe`); the cross-domain "an agent is a workload" reinforcement stays intact.
- **Keep mTLS applied-in-context in `d6-multi-agent`.** The trim is not a deletion of mTLS from the multi-agent note — the note still says "authenticate the peer by its SVID over mutual TLS," because that framing *is* the agent-to-agent angle. What is removed is the re-derivation of *how SVIDs work* (TTL, Workload API, non-exportability, X.509-vs-JWT), which belongs to `d6-identity`.
- Not touching objective ids, labs, `agent-cascade`, or `agent-deleg`.
- Not editing the quiz (separate change).

## Decisions

**D1 — `d6-identity` is the canonical Domain-6 SVID anchor.** It already teaches the SVID as *workload identity* end-to-end and is the note whose thesis is "workload identity vs delegated authority." Ownership belongs where the concept is defined; `d6-multi-agent` consumes it. When trimming, `d6-multi-agent` links to `d6-identity`'s `agent-workload` section (already a natural cross-reference — see `d6-multi-agent` line 22 and the "Related" block line 70) rather than to Domain 1 for the primitive.

**D2 — Trim to the delta, reference the mechanics.** In `d6-multi-agent`'s `agent-mtls` section, keep: identity-not-network-position, mutual authentication of both peers, the SPIFFE-ID allowlist code, and the MAESTRO cross-layer framing. Replace the standalone SVID-mechanics sentences/gotchas ("short-lived, non-exportable … fetches from the Workload API"; "minted and rotated by SPIRE … co-located rogue can't impersonate") and the duplicated SPIFFE-concepts resource link with a one-line reference to `d6-identity` (`agent-workload`). The `agent-mtls` summary row keeps the *identity-not-IP* takeaway and drops the re-stated "short-lived, non-exportable SVID" clause.

**D3 — Spec MODIFY, additive.** Copy the existing requirement block verbatim and add a single scenario capturing the single-source-of-truth rule. The two existing scenarios ("over-broad or stolen delegated token is refused"; "workload identity is distinct from delegated authority") are preserved unchanged — the new scenario is about *where* the SVID is taught within Domain 6, not about the identity/authority distinction itself.

## Risks / Trade-offs

- **Risk: over-trimming removes the multi-agent note's ability to stand alone.** Mitigation — keep mTLS applied-in-context (D2 Non-Goal); a reader of `d6-multi-agent` still sees "peer authenticated by SVID over mTLS," just not the SVID internals. The reference makes the dependency explicit rather than implicit.
- **Risk: readers who skip `d6-identity` lose the mechanics.** Accepted — `d6-identity` is subsection 1 of the domain and `d6-multi-agent` is subsection 4; the ordering already assumes `agent-workload` is read first, and the cross-link names it. This matches how `d6-multi-agent` already defers `agent-deleg` and the action-gate to their owning notes.
- **Trade-off: a small amount of intentional cross-domain redundancy (the `wi-spiffe` back-link) is preserved while the intra-domain redundancy is removed.** This is deliberate — cross-domain reinforcement aids retention; intra-domain duplication just dilutes each note's distinct thesis.
