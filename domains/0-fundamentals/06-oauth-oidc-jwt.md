# Fundamentals: OAuth 2.0 / OIDC / JWT anatomy — the flow and the claims before D1 assumes them

Ramp notes — no exam objective maps here. [`identity-provider.md`](../1-identity-governance/identity-provider.md) names OAuth grant types and OIDC clients as configuration you flip in Keycloak; it never walks a flow or decodes a token from scratch. This note does: trace the authorization-code flow hop by hop (with PKCE), place the other four grant types against it, tell an OIDC ID token from an OAuth access token, and decode a JWT's header and standard claims — so `identity-provider.md`'s `kc-clients` grant-type list and the [d1-keycloak-sso-mfa](../../labs/d1-keycloak-sso-mfa.md) lab's "decode it at jwt.io" step land on already-understood mechanics, not new ones. Read this before [`identity-provider.md`](../1-identity-governance/identity-provider.md); [`d6-identity.md`](../6-agentic-zero-trust/d6-identity.md)'s delegated `act`-claim tokens reuse the same vocabulary later.

## The three parties and the authorization-code flow (with PKCE)

Every OAuth exchange has three parties that are easy to conflate: the **resource owner** (the user), the **client** (the app requesting access — Keycloak calls it a client, Entra calls it an app registration), and the **authorization server** (Keycloak/Entra: authenticates the user and issues tokens). A fourth, the **resource server** (the API being called), trusts tokens the authorization server issues without ever talking to it directly. The **authorization code** grant is the one every other grant type is a variation or restriction of, so trace it hop by hop for a confidential web app:

1. **Authorization request.** The client redirects the browser to the authorization server's `/authorize` endpoint with `response_type=code`, `client_id`, `redirect_uri`, `scope`, a random `state` (CSRF protection — the client checks this comes back unchanged), and — for PKCE — a `code_challenge` derived from a client-generated secret (`code_verifier`).
2. **User authenticates.** The authorization server (Keycloak's browser flow — `kc-mfa`) authenticates the user directly; the client never sees the password.
3. **Authorization code returned.** The browser is redirected back to `redirect_uri` with a short-lived, single-use **authorization code** (not a token) in the query string, plus the original `state`.
4. **Code exchange.** The client — server-side, never in the browser — POSTs the code to the `/token` endpoint with its own credentials (a confidential client's secret/keypair) and, for PKCE, the original `code_verifier`. The authorization server recomputes the `code_challenge` from the verifier and checks it matches what step 1 sent; only the party that started the flow can complete it, even if the code was intercepted in transit.
5. **Tokens issued.** The authorization server returns an **access token** (and, for an OIDC request — `scope=openid` — an **ID token**, and often a **refresh token**) directly to the client over the back channel, never through the browser.

**Why PKCE:** the authorization code alone is a bearer artifact that transits the browser (redirect URI, browser history, a referrer leak, a malicious app registered on the same custom URI scheme) — a public client (SPA, mobile app) can't hold a client secret to prove it's the legitimate recipient at step 4, so PKCE substitutes a per-request secret only the real client ever held. RFC 9700 (the OAuth Security BCP) now recommends PKCE for confidential clients too, as defense in depth against code interception. This is exactly the `kc-clients` "public client → authorization code with PKCE, no secret" rule in `identity-provider.md` — now you've seen why the flow requires it, not just which capability toggle enables it.

## The other four grant types, against the same three parties

- **Implicit** *(legacy — do not enable)* — the authorization server returns the access token directly in the redirect URI fragment, skipping the code-exchange step. No back-channel exchange means no client secret is ever needed *or checked*, and the token is exposed in browser history/referrers with no code-interception defense (PKCE closes this gap without implicit's exposure). Deprecated by RFC 9700; `identity-provider.md`'s `kc-clients` gotcha calling this an audit finding is this grant.
- **Resource Owner Password Credentials (ROPC)** *(legacy — do not enable)* — the user hands their password directly to the client, which POSTs it to `/token` for a token. It defeats the premise of delegated authorization (the authorization server never sees or vets a client-side prompt, and the client now handles raw credentials) and is incompatible with MFA/step-up by construction. Kept alive only for legacy CLI tools migrating off basic auth; `identity-provider.md` calls this "Direct access grants."
- **Client Credentials** — no resource owner at all: the client authenticates as *itself* (`client_id` + secret or keypair) directly to `/token` and gets a token representing the app, not a user. This is `kc-clients`' service-account path — a daemon calling an API with no human present — and the direct ancestor of the workload-identity federation pattern in [`workload-identity.md`](../1-identity-governance/workload-identity.md).
- **Device Authorization (device code)** — for input-constrained devices (a TV, a CLI on a headless host): the device polls `/token` with a `device_code` while the user completes authorization on a *second* device (phone/laptop) via a short displayed code and URL. Same three parties, same tokens issued at the end; only the front channel changes because the device can't render a redirect-capable browser.

Every grant type ends at the same place — the authorization server hands the client an access token (and optionally an ID token, a refresh token) — the four differ only in **how the client proves it's entitled to ask** and **whether a user is present at all**.

## The OIDC ID token is not the OAuth access token

OAuth 2.0 (RFC 6749) is an **authorization** framework — it says nothing about who the user is, only what the client may access, hence the access token. **OIDC layers authentication on top**: request `scope=openid` and the token response includes an **ID token**, a JWT whose entire purpose is telling the *client* who just authenticated. They are not interchangeable, and confusing them is one of the most common OIDC implementation mistakes:

| | ID token | Access token |
|---|---|---|
| Consumer | The client (app) itself | A resource server / API |
| Format | Always a JWT (OIDC mandates it) | JWT or opaque — the resource server's choice |
| `aud` claim | The `client_id` that requested it | The resource server / API the token is for |
| Contains | Identity claims about the user (`sub`, `email`, `acr`…) | Whatever authorization claims the resource server needs (scope, roles) |
| Rule | **Never** send it to an API as a bearer credential | **Never** use it to establish "who is this user" client-side |

Sending an ID token to an API as if it were an access token is a real, exploitable bug: the ID token's `aud` names your client, not the API, so an API that doesn't check `aud` will accept a token that was never meant for it. The `nonce` value the client sent at step 1 of the flow comes back inside the ID token and must be checked to bind the token to *this* login attempt — the ID-token equivalent of `state`'s CSRF protection.

## Decoding a JWT: header, claims, signature

A JWT is three base64url segments joined by `.` — `header.payload.signature` — and decoding the first two needs no library, no secret, and no network call, which is exactly what `jwt.io` (and the [`d1-keycloak-sso-mfa`](../../labs/d1-keycloak-sso-mfa.md) lab) has you do:

```bash
# split on '.', base64url-decode the header and payload segments, pretty-print
TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImFiYzEyMyJ9..."
echo "$TOKEN" | cut -d. -f1 | base64 -d 2>/dev/null | jq .   # header
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq .   # payload/claims
```

**Header** — `alg` (the signing algorithm, e.g. `RS256`) and `kid` (**key ID**: which key in the issuer's JWKS signed this token — required once the issuer rotates keys, which it always eventually does).

**Standard claims** in the payload:

- **`iss`** — issuer: the authorization server's URL. This is what `identity-provider.md`'s `kc-deploy` warns is "trust-critical" — every relying party validates `iss` against its configured issuer, so changing the realm hostname invalidates every token in flight.
- **`aud`** — audience: who the token is *for*. A resource server that skips checking `aud` will accept a token minted for a completely different API — the exact confused-deputy gap the ID-token-vs-access-token table above warns about.
- **`sub`** — subject: the stable, unique identifier of the principal the token is about (a user's Keycloak ID, a service account, a Kubernetes ServiceAccount).
- **`exp`** / **`iat`** — expiry and issued-at, both Unix timestamps. Every verifier must reject an expired token locally, with no network call — that's the point of a stateless bearer token: it authorizes exactly as long as `exp` says and not a second longer.
- **`act`** — the **actor claim** (RFC 8693 §4.1): when a token was minted by delegation rather than direct login, `act` names *who acted on behalf of the subject* — `{"sub": "alice", "act": {"sub": "agent-a"}}` reads "alice, via agent-a." This is the exact claim [`d6-identity.md`](../6-agentic-zero-trust/d6-identity.md)'s `agent-deleg` token-exchange flow relies on to keep the delegating agent visible in the audit trail instead of impersonating the user outright.

**Signature verification** is what turns "a JSON blob I can read" into "a JSON blob I can trust," and it's the part decoding at jwt.io skips: the verifier fetches the issuer's **JWKS** (JSON Web Key Set) — published at `iss` + `/.well-known/openid-configuration`'s `jwks_uri` — picks the public key whose `kid` matches the token header, and checks the signature over `header.payload` against it. Only the authorization server holds the matching private key, so a valid signature proves the authorization server minted this exact, unmodified token; a signature check without also validating `iss`/`aud`/`exp` locally is incomplete, and skipping the JWKS fetch entirely (blindly trusting whatever `alg`/key the token itself claims) is the classic `alg=none` / key-confusion JWT vulnerability class.

## Putting it together

| Concept | Where it's decided | Where D1/D6 build on it |
|---|---|---|
| Authorization code + PKCE | `/authorize` → browser redirect → `/token` | `kc-clients` public/confidential client split |
| Implicit, ROPC (legacy) | `/authorize` or `/token` directly | `kc-clients` "audit finding if enabled" gotcha |
| Client credentials | `/token`, no user | `kc-clients` service accounts; `workload-identity.md` |
| Device code | `/token` polling + a second device | situational — CLI/headless auth |
| ID token vs access token | `scope=openid` in the request | `kc-mfa`/`kc-clients` — who authenticated vs what's authorized |
| `iss`, `aud`, `sub`, `exp`, `iat` | JWT payload | `kc-deploy`'s issuer-URL warning; every resource-server check in the course |
| `act` (actor claim) | JWT payload, delegated tokens only | `d6-identity.md`'s `agent-deleg` — RFC 8693 token exchange |
| JWKS signature verification | `iss/.well-known/openid-configuration` → `jwks_uri` | every offline token validation in the course (`wi-oidc`, `agent-deleg`) |

## Self-check

1. A public SPA client completes the authorization-code flow. What does PKCE protect against that the plain authorization-code flow (no PKCE) does not, and why can't this client just hold a client secret instead?
2. An API rejects a request because it received an ID token instead of an access token. What in the ID token's claims would have told the API to reject it, even without knowing the difference in advance?
3. You decode a JWT and see `alg: "RS256"`, `kid: "abc123"`, `iss: "https://idp.example/realms/oss500"`. Walk the two remaining steps a correct verifier takes before trusting any claim inside it.
4. In `{"sub": "alice", "act": {"sub": "agent-a"}}`, who is the token authorizing, and what would be lost if the token instead just carried `sub: "alice"` with no `act` claim?

## Primary sources
- [RFC 6749 — The OAuth 2.0 Authorization Framework](https://datatracker.ietf.org/doc/html/rfc6749) `[depth]` (~30 min)
- [RFC 7636 — PKCE for OAuth public clients](https://datatracker.ietf.org/doc/html/rfc7636) `[depth]` (~15 min)
- [RFC 9700 — Best Current Practice for OAuth 2.0 Security](https://datatracker.ietf.org/doc/html/rfc9700) `[depth]` (~30 min)
- [OpenID Connect Core 1.0 — ID Token](https://openid.net/specs/openid-connect-core-1_0.html#IDToken) `[depth]` (~15 min)
- [RFC 7519 — JSON Web Token (JWT)](https://datatracker.ietf.org/doc/html/rfc7519) `[depth]` (~20 min)
- [RFC 7517 — JSON Web Key (JWK) / JWKS](https://datatracker.ietf.org/doc/html/rfc7517) `[depth]` (~15 min)
- [RFC 8693 §4.1 — the `act` (actor) claim](https://datatracker.ietf.org/doc/html/rfc8693#section-4.1) `[depth]` (~10 min)
- [jwt.io](https://jwt.io) (reference) — decode a token by hand, no library or network call needed
