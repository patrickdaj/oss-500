# Add an OAuth 2.0 / OIDC / JWT anatomy primer before D1 assumes it

## Why

D1 `identity-provider` names the five OAuth grant types and moves on — it never *walks a flow* — and the labs then have the learner decode JWTs at `jwt.io` as if the token's anatomy were already understood. For this persona the gap is only partly softened: his PKI depth carries token *signing* and JWKS verification, but not the grant-flow choreography (who redirects whom, where the code is exchanged, why PKCE exists) and not the claim semantics (`aud`, `iss`, `exp`, and the `act` actor claim that D6 delegation later turns on). He can read a decoded JWT without knowing which claim gates what, and can name a grant type without being able to trace one.

There is a Linux/containers on-ramp in Phase 0 but no identity on-ramp, so the first place these mechanics *could* be learned is the note that already assumes them.

## What Changes

- Add an **OAuth 2.0 / OIDC / JWT anatomy primer** as a new `0-fundamentals` note (or a D1.0 preamble) ahead of `identity-provider`, that: walks the authorization-code flow end to end (with PKCE) and situates the other four grant types against it; distinguishes the OIDC ID token from the OAuth access token; and decodes a JWT's header and standard claims (`iss`, `aud`, `sub`, `exp`, `iat`, and the `act` actor claim), explaining signature verification against a JWKS.
- Cross-link the primer from `identity-provider` and from the D6 objectives that rely on token-exchange / `act` delegation semantics, so the flow and claim vocabulary are single-sourced.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `oss-curriculum` — adds a requirement that the OAuth/OIDC/JWT mechanics the D1 identity objectives assume are taught (flow walked, claims decoded) before the first note that uses them.

## Impact

- Affected specs: `oss-curriculum` (one ADDED requirement).
- Affected content (at implementation time): a new `0-fundamentals` OAuth/OIDC/JWT note (or D1.0 preamble), with cross-links from `identity-provider` and the D6 token-exchange/delegation objectives.
- Removes the silent dependency on external OAuth/OIDC specs for the D1 identity spine and grounds the `act`/token-exchange semantics D6 later needs.
