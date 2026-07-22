## ADDED Requirements

### Requirement: Overlapping tool families have a selection orientation
When the curriculum teaches multiple tools of the same family across different notes — in particular the multiple certificate authorities (cert-manager, Vault PKI, the Istio/Linkerd mesh CA, and the SPIRE trust-domain CA) — one note SHALL provide a single selection orientation mapping each tool to the use case it owns (edge/ingress TLS vs east-west mesh mTLS vs platform-agnostic SPIFFE SVID vs app/internal PKI), and the other notes teaching a member of that family SHALL cross-reference it, so the learner has one place that contrasts their scopes rather than reconstructing the mapping from scattered coverage.

#### Scenario: A CA-to-use-case map orients the four certificate authorities
- **WHEN** a learner has met the four certificate authorities across `keys-and-certificates.md`, `network-security.md`, and `workload-identity.md`
- **THEN** `keys-and-certificates.md` contains a CA-selection orientation box mapping each CA to its use case (cert-manager → edge/ingress and app TLS lifecycle, Vault PKI → app/internal PKI, Istio/Linkerd CA → east-west mesh mTLS, SPIRE → platform-agnostic SPIFFE SVID), and the mesh note (`net-mesh`) and SPIFFE note (`wi-spiffe`) each cross-link to that box
