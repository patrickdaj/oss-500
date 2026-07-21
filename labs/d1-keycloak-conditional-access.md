# Lab d1: Keycloak Conditional Access, Federation & Consent

Build step-up MFA for privileged users, broker to an external IdP, and gate OAuth consent — the Conditional Access, federation, and consent controls the exam tests, on open source.

**Objectives covered**

| id | Objective |
|---|---|
| `kc-ca` | Implement conditional access via authentication flows and authorization policies |
| `kc-federation` | Configure identity federation and brokering across SAML/OIDC providers |
| `kc-consent` | Manage OAuth scopes, client scopes, and consent |

**SC-500 correspondence**: Conditional Access (signals → grant; step-up MFA; per-resource policy) · Entra external identities / federation (B2B, federated SAML/OIDC) · OAuth permission grants and consent (illicit-consent mitigation).

**Prerequisites**
- [`lab-infra/identity`](../lab-infra/identity/) up (`./up.sh`) with the `oss500` realm, `alice` (engineer), and `dave` (admin) from [d1-keycloak-sso-mfa](d1-keycloak-sso-mfa.md) Part A
- Notes read: [identity-provider.md](../domains/1-identity-governance/identity-provider.md)

**Estimated time**: 2–3 h · $0 (local)

Reuse the authenticated `kcadm` alias from the SSO lab:
```bash
KC="kubectl -n oss500-identity exec -i deploy/keycloak -- /opt/bitnami/keycloak/bin/kcadm.sh"
$KC config credentials --server http://localhost:8080 --realm master --user admin --password "$KEYCLOAK_ADMIN_PASSWORD"
```

## Steps

### Part A — Step-up MFA via a conditional flow for admins (`kc-ca`)

Conditional access = *if privileged, then require a second factor*. In Keycloak this is a `CONDITIONAL` subflow keyed on a role condition — the flow-time decision — plus an Authorization Services policy for the per-resource decision.

1. In the admin console (realm `oss500`): **Authentication → Flows** → duplicate **browser** → name it `browser-stepup` → **Bind flow → Browser flow**.
2. Inside `browser-stepup`, in the forms subflow, ensure the **Browser - Conditional OTP** subflow is `Conditional`, and add/verify its condition:
   - Add execution **Condition - User Role** → set **Requirement = Required** → configure **User role = `realm-admin`**.
   - Set the **OTP Form** execution in that subflow to **Required**.
   - Leave the top-level username/password `Required`. Net effect: everyone authenticates with a password; **only members of `admins`/`realm-admin` are additionally forced through OTP** — step-up MFA scoped to privileged users, exactly an Entra CA policy targeting a directory-role group and requiring MFA.
3. (Per-resource authz decision.) Turn `reports-web` into a resource server and add a **time-based** policy — the fine-grained cousin of a CA grant ("only during business hours"):
   ```bash
   # Enable authorization services on the client, then (admin console → client → Authorization):
   #  Resources:   report-export  (scope: export)
   #  Policies:    business-hours  →  type: Time,  Hour 9–17,  logic POSITIVE
   #  Permissions: export-perm  →  resource report-export + scope export + policy business-hours
   $KC update clients/$($KC get clients -r oss500 -q clientId=reports-web --fields id --format csv | tail -1 | tr -d '"') \
     -r oss500 -s authorizationServicesEnabled=true -s serviceAccountsEnabled=true
   ```
   Authorization Services is **deny-by-default**: with no matching permission, the `export` scope is refused. Note a break-glass account must be excluded from any mandatory factor, mirroring excluding break-glass accounts from a blocking CA policy.

### Part B — Identity brokering to an upstream OIDC provider (`kc-federation`)

Brokering delegates *authentication* to an external IdP while Keycloak still issues its own tokens. (Distinct from LDAP **user federation**, which imports a user store.) The simplest, fully-local upstream is a second realm.

4. Create an upstream realm to act as the "external" IdP, with a broker client and a test user:
   ```bash
   $KC create realms -s realm=partner -s enabled=true
   $KC create users  -r partner -s username=carol -s enabled=true -s email=carol@partner.example
   $KC set-password  -r partner --username carol --new-password 'Passw0rd!'
   $KC create clients -r partner \
     -s clientId=oss500-broker -s protocol=openid-connect -s publicClient=false \
     -s standardFlowEnabled=true \
     -s 'redirectUris=["http://keycloak.oss500.local:8080/realms/oss500/broker/partner-oidc/endpoint"]'
   BSECRET=$($KC get clients/$($KC get clients -r partner -q clientId=oss500-broker --fields id --format csv | tail -1 | tr -d '"')/client-secret -r partner --fields value --format csv | tail -1 | tr -d '"')
   ```
5. In the `oss500` realm, add an **OIDC Identity Provider** pointed at the `partner` realm (use its discovery URL to import endpoints):
   ```bash
   $KC create identity-provider/instances -r oss500 \
     -s alias=partner-oidc -s providerId=oidc -s enabled=true \
     -s 'config.authorizationUrl=http://keycloak.oss500.local:8080/realms/partner/protocol/openid-connect/auth' \
     -s 'config.tokenUrl=http://keycloak.oss500.local:8080/realms/partner/protocol/openid-connect/token' \
     -s 'config.userInfoUrl=http://keycloak.oss500.local:8080/realms/partner/protocol/openid-connect/userinfo' \
     -s 'config.clientId=oss500-broker' -s "config.clientSecret=$BSECRET" \
     -s 'config.defaultScope=openid email profile'
   ```
6. Add an **identity-provider mapper** so an upstream claim becomes a local attribute/role — the trust-critical step (never blindly map an upstream `groups` claim into a privileged local role). In the console: **Identity providers → partner-oidc → Mappers → Add**: map upstream `email` → local user attribute. Confirm the **First Login Flow** is set (default links/creates the local user).

### Part C — Client scopes & consent (`kc-consent`)

7. Create an **optional** client scope, consent-visible, that an app must explicitly request:
   ```bash
   $KC create client-scopes -r oss500 \
     -s name=reports:export -s protocol=openid-connect \
     -s 'attributes."display.on.consent.screen"=true' \
     -s 'attributes."consent.screen.text"=Export report data'
   ```
8. Attach it as **optional** (not default) to `reports-web`, and turn **Consent Required** on for that client (third-party apps should always require consent):
   ```bash
   WID=$($KC get clients -r oss500 -q clientId=reports-web --fields id --format csv | tail -1 | tr -d '"')
   SID=$($KC get client-scopes -r oss500 --fields id,name --format csv | grep reports:export | cut -d, -f1 | tr -d '"')
   $KC update clients/$WID/optional-client-scopes/$SID -r oss500
   $KC update clients/$WID -r oss500 -s consentRequired=true -s fullScopeAllowed=false   # fullScope off = least-privilege token roles
   ```

## Verification

- **Step-up MFA is scoped, and observable**: sign in to `http://keycloak.oss500.local:8080/realms/oss500/account` as `alice` (engineer) → password only, no OTP. Sign in as `dave` (admin/`realm-admin`) → password **then an OTP challenge**. Same realm, same flow — only the role differs. That is conditional access working.
- **Brokered login round-trips**: on the `oss500` account-console login page a **"partner-oidc"** button appears; clicking it redirects to the `partner` realm, you log in as `carol`, and you land back in `oss500` **authenticated with an oss500-issued token** (the app never sees the upstream token). Confirm a linked local user was created under **Users**.
- **Consent is visible and revocable**: initiate an authorization-code login to `reports-web` requesting `scope=openid reports:export` → Keycloak shows a **consent screen listing "Export report data"**. After granting, the user sees the app under **Account console → Applications** and can **revoke** it; the grant reappears as required on next login. This is the illicit-consent audit/revoke surface.

## Teardown
- `cd lab-infra/identity && ./down.sh`

## What the exam asks
- **Conditional access splits by *when* the decision happens**: flow conditions decide at login (get in / step-up MFA); Authorization Services decides per-request, per-resource (deny-by-default). Step-up MFA = a `CONDITIONAL` subflow keyed on a role, not a global toggle.
- **Brokering ≠ user federation**: "log in with the partner's IdP" is brokering (delegate authN, Keycloak still issues its own token); "authenticate against corporate AD/LDAP" is user federation (import a user store). SAML brokering trust depends on signed assertions + correct metadata.
- **First Login Flow + IdP mappers** are the security-critical link — an attacker-controlled upstream claim mapped to an admin role is an escalation path.
- **Client scopes: Default (always in token) vs Optional (requested at runtime)**; require **Consent Required** for third-party clients; the illicit-consent playbook is require-consent + least-privilege scopes + **revoke the recorded grant** (the Entra OAuth-grant revocation analogue). Turn **Full Scope Allowed off** to keep token roles least-privilege.
