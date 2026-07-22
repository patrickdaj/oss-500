## MODIFIED Requirements

### Requirement: An agent has a distinct workload identity and a scoped delegated authority
The `d6-identity` subsection SHALL teach and demonstrate that an agent is a principal with two separate identities: a **workload identity** (a SPIRE-issued SPIFFE SVID for the agent process) and a **delegated authority** to act for a user (a scoped, short-lived OAuth token minted via Keycloak Token Exchange, RFC 8693). The delegated token SHALL be least-privilege and time-limited, not a long-lived agent credential.

#### Scenario: An over-broad or stolen delegated token is refused
- **WHEN** an agent presents a delegated token at a resource for an action outside the token's scope (or a token that has expired)
- **THEN** the resource refuses the request, demonstrating that the delegated authority — not the agent's mere existence — bounds what it can do

#### Scenario: Workload identity is distinct from delegated authority
- **WHEN** the `d6-identity` note and lab are followed
- **THEN** the learner can distinguish the agent's SPIFFE workload identity (who the process is) from its RFC 8693 on-behalf-of token (what it may do for which user), and cite the NIST 800-207 / RFC 8693 / SPIFFE standards behind each

#### Scenario: The SVID mechanics are taught once within Domain 6
- **WHEN** the `d6-identity` and `d6-multi-agent` notes are compared for how each covers SPIFFE SVID mechanics (short-lived and non-exportable, fetched from the SPIRE Workload API, X.509-SVID mTLS vs JWT-SVID bearer, a co-located rogue cannot obtain a peer's SVID)
- **THEN** `d6-identity` (`agent-workload`) SHALL be the single Domain 6 owner of that explanation and `d6-multi-agent` (`agent-mtls`) SHALL reference it rather than restate it, contributing only the net-new agent-to-agent authorization delta (a peer is authorized by its SPIFFE ID rather than by network position, and privilege does not launder across the trust chain), while both notes SHALL preserve their back-link to the Domain 1 canonical `workload-identity.md` (`wi-spiffe`)
