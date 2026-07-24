## ADDED Requirements

### Requirement: OAuth 2.0 / OIDC / JWT anatomy is taught before D1 assumes it
The curriculum SHALL contain an OAuth 2.0 / OIDC / JWT anatomy primer — as a `0-fundamentals` note or a D1 preamble placed ahead of `identity-provider` — that walks the authorization-code flow end to end (including PKCE) and situates the other four grant types against it, distinguishes the OIDC ID token from the OAuth access token, and decodes a JWT's header and standard claims (`iss`, `aud`, `sub`, `exp`, `iat`, and the `act` actor claim), including how a signature is verified against a JWKS. The primer SHALL let the learner trace at least one full grant flow and read what each decoded-JWT claim gates from course materials alone, and SHALL be cross-linked from `identity-provider` and from the D6 objectives that rely on token-exchange / `act` delegation semantics rather than re-teaching those mechanics.

#### Scenario: A grant flow is walked before identity-provider uses it
- **WHEN** a learner opens `identity-provider`, which names the five grant types
- **THEN** a linked primer has already walked the authorization-code flow end to end (with PKCE) and placed the other grant types against it, so the learner can trace a flow rather than only name one

#### Scenario: Decoded JWT claims are meaningful
- **WHEN** a lab has the learner decode a JWT at `jwt.io`
- **THEN** the primer has already taught what `iss`, `aud`, `sub`, `exp`, `iat`, and `act` each mean and how the signature is verified against a JWKS, so the learner knows which claim gates what

#### Scenario: D6 delegation reuses the same primer
- **WHEN** a learner reaches the D6 objectives that turn on token-exchange and `act` actor-claim delegation
- **THEN** those notes cross-link the same primer rather than re-deriving OAuth/OIDC/JWT semantics
