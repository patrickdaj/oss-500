# Tasks

## 1. Trim the duplicated SVID mechanics in `d6-multi-agent`
- [x] 1.1 In `domains/6-agentic-zero-trust/d6-multi-agent.md`, `agent-mtls` section, keep the net-new agent-to-agent angle: authorize a peer by its SPIFFE ID (not IP/subnet/"inside the mesh"), mutual TLS with both peers proving identity, the SPIFFE-ID allowlist code block, and the MAESTRO cross-layer framing.
- [x] 1.2 Replace the re-derived SVID-mechanics prose (line ~13: "short-lived, non-exportable X.509 identity document it fetches from the SPIRE Workload API") and gotchas (line ~27: "short-lived and fetched from the Workload API … never holds long-lived key material"; line ~22/line 31 wording "minted and rotated by SPIRE … a co-located process cannot obtain agent-a's SVID") with a one-line reference to `d6-identity.md` (`agent-workload`) as the owner of the SVID/mTLS primitive.
- [x] 1.3 Remove the duplicated SPIFFE-concepts SVID resource link (line ~31) that restates `d6-identity`'s primitive; keep resources specific to the multi-agent/peer-authz angle (MAESTRO, federation walkthrough).
- [x] 1.4 Update the `agent-mtls` summary-table row (line ~76) to keep the identity-not-IP takeaway and drop the re-stated "short-lived, non-exportable SVID" clause (now owned by `d6-identity`).

## 2. Confirm `d6-identity` remains the canonical owner
- [x] 2.1 Verify `domains/6-agentic-zero-trust/d6-identity.md` `agent-workload` section still carries the full SVID mechanics (short-lived/attested, Workload-API-fetched, X.509-SVID vs JWT-SVID, per-principal SVIDs) — no substantive edit expected; it is the reference target.

## 3. Preserve back-links and verify no lost content
- [x] 3.1 Confirm both notes still back-link the Domain 1 canonical `domains/1-identity-governance/workload-identity.md` (`wi-spiffe`) — the cross-domain reinforcement is intentional and must not be weakened.
- [x] 3.2 Diff the trimmed `d6-multi-agent` against `d6-identity` to confirm every SVID mechanic removed from `d6-multi-agent` is present in `d6-identity` (no coverage deleted, only de-duplicated).

## 4. Validate
- [x] 4.1 Run `npm run lint:links` (oss-500) — new/edited cross-links resolve and every learning-resource link deep-links or is marked `(reference)`.
- [x] 4.2 Run `openspec validate dedup-agent-workload-identity --strict` and confirm it passes.
