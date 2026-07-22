## Context

Four certificate authorities appear across the curriculum, each minting short-lived certs, each taught in isolation:

- `keys-and-certificates.md` (Domain 2) — **cert-manager** Issuers/ClusterIssuers (`cert-issuer`/`cert-lifecycle`) for edge/ingress and app TLS, and the **Vault PKI** `vault` issuer as a CA for app/internal PKI.
- `network-security.md` (Domain 2, `net-mesh`) — the **Istio/Linkerd mesh CA** (`istio-ca` / Linkerd `identity`) minting east-west mTLS SVIDs to sidecars.
- `workload-identity.md` (Domain 1, `wi-spiffe`) — the **SPIRE trust-domain CA** issuing platform-agnostic SPIFFE SVIDs for service-to-service mTLS across clusters/VMs/clouds.

Each note is strong on its own CA. What is missing is one place that answers "there are four CAs here — which one, when?" A learner has to reconstruct the mapping themselves. This change adds that orientation and cross-links it, changing nothing about the individual coverage.

## Goals / Non-Goals

**Goals:**
- Give the learner one CA → use-case selection map: edge/ingress TLS (cert-manager), east-west mesh mTLS (Istio/Linkerd CA), platform-agnostic SPIFFE SVID (SPIRE), app/internal PKI (Vault PKI).
- Make the mesh and SPIFFE notes point to that single map so the orientation is discoverable from where the extra CAs are introduced.

**Non-Goals:**
- Not moving or duplicating any CA's existing deep coverage — each stays in its note.
- No new objective, no tracker change (this is orientation over existing objectives).
- Not a general PKI tutorial — a compact selection box, not new conceptual content.

## Decisions

**D1 — The orientation box lives in `keys-and-certificates.md`.** This note already owns the certificate-lifecycle narrative and already introduces two of the four CAs (cert-manager and the `vault` PKI issuer), so a "which CA when" map sits most naturally beside them; a reader here is already in "certificate authority" headspace. *Alternatives rejected:* the mesh note (`network-security.md`) is scoped to east-west networking and only sees one CA; `workload-identity.md` is Domain 1 identity, one domain away from the cert-lifecycle home. A brand-new standalone note would be heavier than a cross-reference box warrants and would orphan the map from the lifecycle content it belongs with.

**D2 — Cross-links, not copies.** The mesh note and the SPIFFE note each gain a one-line pointer to the box rather than a repeated table, keeping a single source of truth (avoids the duplication the course's dedup changes fight) while making the map reachable from where the mesh CA and SPIRE CA are taught.

**D3 — CA → use-case, four rows.** The box maps each CA to the one job it owns: cert-manager → edge/ingress + app TLS lifecycle; Vault PKI → app/internal PKI (and the `vault` issuer backing cert-manager); Istio/Linkerd CA → east-west mesh mTLS; SPIRE → platform-agnostic SPIFFE SVID beyond a single mesh. Framed as "which CA when," not a feature comparison.

## Risks / Trade-offs

- **Overlap with each CA's own section.** → The box is a *selector* (one line per CA pointing at its use case and its home section), not new teaching; the deep content stays put and the box links to it.
- **Cross-links drift if a note is renamed.** → Use the same relative-link style already used between these notes; `lint:links` catches breakage.
- **Placement could feel Domain-2-centric for the SPIRE (Domain 1) CA.** → Accepted: the cert-lifecycle note is the strongest single home for a CA map, and the SPIFFE note's cross-link resolves discoverability from Domain 1.

## Open Questions

- None material — scope is one box plus two cross-links.
