# Tasks — add-oauth-oidc-jwt-primer

## 1. Author the primer

- [x] 1.1 Add an OAuth 2.0 / OIDC / JWT anatomy primer as a `0-fundamentals` note (or a D1.0 preamble) placed ahead of `identity-provider`.
- [x] 1.2 Walk the authorization-code flow end to end (with PKCE) and situate the other four grant types against it.
- [x] 1.3 Distinguish the OIDC ID token from the OAuth access token.
- [x] 1.4 Decode a JWT's header and standard claims (`iss`, `aud`, `sub`, `exp`, `iat`, `act`) and explain signature verification against a JWKS.

## 2. Cross-link the reuse sites

- [x] 2.1 Cross-link the primer from `identity-provider`.
- [x] 2.2 Cross-link the primer from the D6 token-exchange / `act` delegation objectives.
- [x] 2.3 Confirm those notes no longer assume the flow/claim mechanics without a link (single-sourcing).

## 3. Validation

- [x] 3.1 Run `openspec validate add-oauth-oidc-jwt-primer --type change --strict` and confirm it passes.
