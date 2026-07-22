## Why

The course teaches **four certificate authorities** that all mint short-lived certs, but scattered across three notes with **no single "which CA when" orientation** — so a learner meets four CAs without one place contrasting their scopes:

- **cert-manager** Issuer/ClusterIssuer — edge/ingress and app TLS certificate lifecycle (`domains/2-secrets-data-networking/keys-and-certificates.md`, `cert-issuer`/`cert-lifecycle`)
- **Vault PKI** (`vault` issuer / PKI engine as CA) — app/internal PKI, backing cert-manager (same note)
- **Istio/Linkerd mesh CA** (`istio-ca` / Linkerd `identity`) — east-west mesh mTLS SVIDs (`domains/2-secrets-data-networking/network-security.md`, `net-mesh`)
- **SPIRE trust-domain CA** — platform-agnostic SPIFFE SVIDs for service-to-service mTLS anywhere (`domains/1-identity-governance/workload-identity.md`, `wi-spiffe`)

Each note explains its own CA well, but nothing maps CA → use case, so a learner can't tell why the course runs four of them or which to reach for. This is a **differentiation gap, not duplication** — the fix is additive.

## What Changes

- **Add a short "which CA when" orientation box** to `keys-and-certificates.md` (the natural home — it already owns the certificate-lifecycle story and the `vault` PKI issuer): a compact CA → use-case selection map (edge/ingress TLS vs east-west mesh mTLS vs SPIFFE SVID vs app/internal PKI).
- **Cross-link that box** from the mesh note (`network-security.md`, `net-mesh`) and the SPIFFE note (`workload-identity.md`, `wi-spiffe`) so a learner meeting the mesh CA or the SPIRE CA is pointed to the one contrasting map.
- Nothing is deleted; each CA's own deep coverage stays where it is.

## Capabilities

### Modified Capabilities
- `oss-curriculum`: ADD a requirement that overlapping tool families (here, the four CAs) carry a single selection orientation — one note provides a CA-to-use-case map the others reference.

## Impact

- **Content**: `domains/2-secrets-data-networking/keys-and-certificates.md` gains the CA-selection orientation box; `domains/2-secrets-data-networking/network-security.md` and `domains/1-identity-governance/workload-identity.md` each gain a one-line cross-link to it.
- **No tracker change**: no new objective ids; existing `cert-issuer`, `cert-lifecycle`, `net-mesh`, `wi-spiffe` are unchanged, so `tracker.yaml` and study-hub domain/objective counts stay green.
- **Links**: any external links follow the `resource-citation` standard so `lint:links` stays green.
