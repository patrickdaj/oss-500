# Lab d1: Keycloak SSO & MFA

Stand up an OIDC identity provider, model a realm, and prove MFA and app identity work — the Entra ID controls the exam tests, on open source.

**Objectives covered**

| id | Objective |
|---|---|
| `kc-deploy` | Deploy an OIDC/SAML identity provider and model realms, users, and groups (Entra ID equivalent) |
| `kc-clients` | Configure identity for applications: OIDC clients, service accounts, and scopes |
| `kc-mfa` | Configure authentication methods, including MFA, OTP, and WebAuthn passwordless |

**SC-500 correspondence**: Microsoft Entra ID (tenant/realm, users, groups) · Entra authentication methods / MFA (OTP, FIDO2 passwordless) · Enterprise apps & app registrations (OIDC clients, service principals, service accounts).

**Prerequisites**
- [`lab-infra/identity`](../lab-infra/identity/) up (`cp admin-password.env.example admin-password.env` then `./up.sh`)
- `/etc/hosts`: `127.0.0.1  keycloak.oss500.local`
- Notes read: [identity-provider.md](../domains/1-identity-governance/identity-provider.md)

**Estimated time**: 2–3 h · $0 (local)

Throughout, open a shell in the Keycloak pod and authenticate `kcadm` once (reuse the session):

```bash
KC="kubectl -n oss500-identity exec -i deploy/keycloak -- /opt/bitnami/keycloak/bin/kcadm.sh"
$KC config credentials --server http://localhost:8080 --realm master \
  --user admin --password "$KEYCLOAK_ADMIN_PASSWORD"
```

## Challenge

Build a realm-scoped identity model in Keycloak that proves three things the exam maps straight to Entra ID: MFA is enforced by the authentication **flow** (not just registered on a user), a service-account (daemon) client can authenticate *as itself*, and a **public** client cannot. Then push MFA one step further into a phishing-resistant, passwordless factor.

Concretely, you must reach these observables (the exact checks are in Verification below — build toward them, don't peek at the commands yet):
- Signing in as `alice` at the realm's account console is forced through **Configure OTP** on first login and prompted for a 6-digit code afterward — and turning off the flow's OTP requirement makes that challenge vanish, proving enforcement lives in the flow.
- A client-credentials call as the `reports-daemon` service-account client returns a JWT — no human involved.
- The same call as the public `reports-spa` client is rejected (`unauthorized_client` / not allowed for direct access grants) — a public client cannot authenticate as itself.
- Pointing WebAuthn's Relying Party ID at the wrong hostname breaks passkey registration in the browser.

No solution code below — write it yourself in **Build it (guided)**, then check your work against **Reference solution**.

## Build it (guided)

### Part A — Deploy realm, users, and groups (`kc-deploy`)

1. **Create the application realm.** Never model apps in `master` — it is the admin plane, like the tenant's privileged plane. Your turn: a `$KC create realms` call with `realm=oss500`, `enabled=true`.
2. **Create two groups and a realm role.** Groups are the Entra security-group analogue; the realm role is the directory-role analogue. Your turn: `$KC create groups -r oss500` for `engineers` and for `admins`, plus `$KC create roles -r oss500` for a role named `realm-admin`.
3. **Create two users and set passwords.** `alice` is a normal engineer; `dave` is an admin (used for step-up MFA in the conditional-access lab). Your turn: `$KC create users -r oss500` for both (`enabled=true`, an email each), then `$KC set-password -r oss500` for each.
4. **Put `alice` in `engineers`, `dave` in `admins`, and map the `realm-admin` role to the `admins` group** so membership drives authorization — this is the group-role-mapping pattern, not a per-user grant. Your turn: the `$KC add-roles` call that maps `realm-admin` onto the `admins` group. (In the admin console, confirm **Users → dave → Groups → admins**, and **Groups → admins → Role mapping → realm-admin**.)
5. Inspect the OIDC issuer this realm now publishes — the value every client trusts:
   ```bash
   curl -s http://localhost:8080/realms/oss500/.well-known/openid-configuration | jq '.issuer, .token_endpoint'
   ```

### Part B — OIDC client + service account (`kc-clients`)

6. **Create a confidential web client** (authorization-code flow) — the app-registration/enterprise-app equivalent. Note the **exact** redirect URI (a wildcard `*` redirect is a token-theft finding), and turn off ROPC (`directAccessGrantsEnabled=false`) — legacy, audit finding. Your turn: the `$KC create clients -r oss500` call for `clientId=reports-web`, `publicClient=false`, `standardFlowEnabled=true`, the exact `redirectUris`, and `directAccessGrantsEnabled=false`.
7. **Create a service-account client** — a daemon identity that authenticates *as itself* with the client-credentials grant (the Entra application-permission analogue). Your turn: the `$KC create clients -r oss500` call for `clientId=reports-daemon`, `publicClient=false`, `standardFlowEnabled=false`, `serviceAccountsEnabled=true`. Once it exists, pull its id and secret (you'll need `$SECRET` for Verification):
   ```bash
   CID=$($KC get clients -r oss500 -q clientId=reports-daemon --fields id --format csv | tail -1 | tr -d '"')
   SECRET=$($KC get clients/$CID/client-secret -r oss500 --fields value --format csv | tail -1 | tr -d '"')
   echo "daemon secret: $SECRET"
   ```
8. **Create a public client** (SPA) — no secret, PKCE required. This contrast matters: a secret in a public client is the classic error. Your turn: the `$KC create clients -r oss500` call for `clientId=reports-spa`, `publicClient=true`, `standardFlowEnabled=true`, a localhost `redirectUris`, and the PKCE attribute forcing `S256`.

### Part C — Enable MFA: TOTP + WebAuthn passwordless (`kc-mfa`)

9. **Force TOTP enrolment realm-wide** (the bootstrap-enrolment mechanism, like an Entra registration campaign). Your turn: a `$KC update realms/oss500` call setting `requiredActions` to include the `CONFIGURE_TOTP` action, `enabled=true`, `defaultAction=true`.
10. **Confirm the browser flow carries an OTP execution set to `REQUIRED`** — this is what actually *enforces* the second factor; MFA lives in the flow, not on the user. In the admin console: **Authentication → Flows → browser → Browser - Conditional OTP**. Your turn: for an unconditional MFA baseline, what does the OTP execution's `Requirement` need to be set to?
11. **Enable WebAuthn passwordless** (FIDO2 — the phishing-resistant path). Think through the pieces before opening the console: a policy that fixes the Relying Party identity, a flow execution that offers the passwordless authenticator as an alternative, and a required action that drives enrollment. Your turn:
    - **Authentication → Policies → WebAuthn Passwordless Policy**: what must the Relying Party ID equal for registration to work at all (hint — it's the same value as the hostname you browse to), and what should User Verification be set to?
    - **Authentication → Flows → browser** → duplicate it, add a WebAuthn passwordless execution to the username/password subflow — as what requirement level, so it's offered as an option rather than mandatory? Then bind your duplicated flow as the realm's browser flow.
    - Which required action, once added under **Authentication → Required actions**, actually drives users to register a passkey?

## Verification

- **MFA challenge is observable**: browse to `http://keycloak.oss500.local:8080/realms/oss500/account`, sign in as `alice` → Keycloak forces the **Configure OTP** screen (QR code), then on subsequent logins prompts for the 6-digit code. Removing the OTP execution's `Required` and re-testing shows the challenge disappear — proving enforcement is in the flow, not the user.
- **Service account issues a token** (daemon identity, no human):
  ```bash
  curl -s -X POST http://localhost:8080/realms/oss500/protocol/openid-connect/token \
    -d grant_type=client_credentials -d client_id=reports-daemon -d client_secret="$SECRET" \
    | jq -r .access_token | cut -c1-40    # a JWT is returned — decode it at jwt.io to see the service-account subject
  ```
- **Public client rejected from confidential flow**: attempting client-credentials as the public `reports-spa` (no secret) returns `unauthorized_client` / `Client not allowed for direct access grants` — a public client cannot authenticate as itself:
  ```bash
  curl -s -X POST http://localhost:8080/realms/oss500/protocol/openid-connect/token \
    -d grant_type=client_credentials -d client_id=reports-spa | jq .error
  ```
- **WebAuthn RP-ID mismatch is observable**: temporarily set the Relying Party ID to a wrong hostname and attempt passkey registration → the browser rejects it, demonstrating the hostname-binding invariant.

## Reference solution
Build it yourself first; check after.

### Part A — Deploy realm, users, and groups (`kc-deploy`)

```bash
# 1. Create the application realm
$KC create realms -s realm=oss500 -s enabled=true

# 2. Two groups + a realm role
$KC create groups -r oss500 -s name=engineers
$KC create groups -r oss500 -s name=admins
$KC create roles  -r oss500 -s name=realm-admin

# 3. Two users + passwords
$KC create users -r oss500 -s username=alice -s enabled=true -s email=alice@oss500.local
$KC create users -r oss500 -s username=dave  -s enabled=true -s email=dave@oss500.local
$KC set-password -r oss500 --username alice --new-password 'Passw0rd!'
$KC set-password -r oss500 --username dave  --new-password 'Passw0rd!'

# 4. Map realm-admin onto the admins group (via group role-mapping)
$KC add-roles -r oss500 --gname admins --rolename realm-admin
```
(In the admin console, confirm **Users → dave → Groups → admins**, and **Groups → admins → Role mapping → realm-admin**.)

### Part B — OIDC client + service account (`kc-clients`)

```bash
# 6. Confidential web client (authorization-code flow)
$KC create clients -r oss500 \
  -s clientId=reports-web -s protocol=openid-connect \
  -s publicClient=false -s standardFlowEnabled=true \
  -s 'redirectUris=["https://reports.oss500.local/*"]' \
  -s directAccessGrantsEnabled=false        # ROPC off — legacy, audit finding

# 7. Service-account client (client-credentials / daemon identity)
$KC create clients -r oss500 \
  -s clientId=reports-daemon -s protocol=openid-connect \
  -s publicClient=false -s standardFlowEnabled=false \
  -s serviceAccountsEnabled=true
CID=$($KC get clients -r oss500 -q clientId=reports-daemon --fields id --format csv | tail -1 | tr -d '"')
SECRET=$($KC get clients/$CID/client-secret -r oss500 --fields value --format csv | tail -1 | tr -d '"')
echo "daemon secret: $SECRET"

# 8. Public client (SPA) — no secret, PKCE required
$KC create clients -r oss500 \
  -s clientId=reports-spa -s protocol=openid-connect \
  -s publicClient=true -s standardFlowEnabled=true \
  -s 'redirectUris=["http://localhost:3000/*"]' \
  -s 'attributes."pkce.code.challenge.method"=S256'
```

### Part C — Enable MFA: TOTP + WebAuthn passwordless (`kc-mfa`)

```bash
# 9. Force TOTP enrolment realm-wide
$KC update realms/oss500 \
  -s 'requiredActions=[{"alias":"CONFIGURE_TOTP","name":"Configure OTP","enabled":true,"defaultAction":true}]'
```
10. In the admin console: **Authentication → Flows → browser → Browser - Conditional OTP**. For an unconditional MFA baseline, set the OTP execution `Requirement = Required`.
11. WebAuthn passwordless (FIDO2):
    - **Authentication → Policies → WebAuthn Passwordless Policy**: set **Relying Party ID = `keycloak.oss500.local`** (must equal the public hostname or registration silently fails), User Verification = `required`.
    - **Authentication → Flows → browser** → duplicate it, add a **WebAuthn Passwordless Authenticator** execution as `ALTERNATIVE` to the username/password subflow, then **Bind flow → Browser flow**.
    - Add the `webauthn-register-passwordless` required action under **Authentication → Required actions**.

## Teardown
- `cd lab-infra/identity && ./down.sh`

## What the exam asks
- **MFA is enforced in the authentication flow**, not toggled on a user — "method registered" (available) vs "flow requires it" (enforced) mirrors Entra methods policy vs a CA grant requiring MFA.
- **Confidential vs public client**: confidential holds a secret and can use client-credentials; public (SPA/native) uses PKCE and must never carry a secret. A secret in a SPA is the classic misconfiguration.
- **Service account = daemon/app identity** (client-credentials grant), the Entra application-permission analogue — no signed-in user, permissions via role mappings on the service-account user.
- **WebAuthn/FIDO2 passwordless = phishing-resistant**; TOTP is MFA but phishable. The Relying Party ID must equal the public hostname (the top WebAuthn misconfiguration).
- **Exact redirect URIs** and disabling legacy grants (ROPC/implicit) are hardening findings — the same as over-broad Entra reply URLs and enabled legacy auth.
