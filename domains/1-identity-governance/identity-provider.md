# Secure access to resources by using an identity provider (Keycloak)

Domain 1, subsection 1 (`d1-idp`). Keycloak is the open-source stand-in for Microsoft Entra ID: an OIDC/SAML identity provider that owns your realms, users, groups, clients, authentication flows, MFA, brokering, and consent. Everything an SC-500 candidate has to reason about on Entra — how apps trust a token, how MFA is enforced, how conditional access decides, how OAuth consent is granted — has a concrete, inspectable equivalent here that you deploy and break yourself. Primary labs: [d1-keycloak-sso-mfa](../../labs/d1-keycloak-sso-mfa.md) and [d1-keycloak-conditional-access](../../labs/d1-keycloak-conditional-access.md); the lab-infra component is [`lab-infra/identity`](../../lab-infra/identity/) (Keycloak on the kind cluster).

## Deploy an OIDC/SAML identity provider and model realms, users, and groups (Entra ID equivalent)

*Objective: `kc-deploy` · OSS: Keycloak ≈ SC-500: Microsoft Entra ID · Lab: [d1-keycloak-sso-mfa](../../labs/d1-keycloak-sso-mfa.md)*

An identity provider (IdP) is the single authority that authenticates principals and issues tokens applications trust. In Entra ID that authority is your **tenant**; in Keycloak it is a **realm**. A realm is a fully isolated namespace of users, groups, roles, clients, and keys — the direct analogue of an Entra tenant. Keycloak ships one built-in **master realm** used only to administer other realms (treat it like the tenant's Global Admin plane — you never register application workloads there). You create a per-application-domain realm (`oss500`) and model identities inside it, exactly as you'd keep workloads out of the tenant's privileged plane in Entra.

Deployment decisions that are painful to change later mirror the Entra "which edition / which tenant" choices: the **database backend** (Keycloak needs a real RDBMS — Postgres — for anything beyond `start-dev`; the H2 dev database loses state), the **hostname/issuer URL** (bakes into every token's `iss` claim and every client's discovery document at `/.well-known/openid-configuration`, so changing it invalidates trust), and **production mode** (`kc.sh start` requires HTTPS and a set hostname; `start-dev` disables both). In the lab we run the official `quay.io/keycloak/keycloak` image via Helm with a bundled Postgres:

```bash
# lab-infra/identity/up.sh wraps this
helm upgrade --install keycloak oci://registry-1.docker.io/bitnamicharts/keycloak \
  -n oss500-identity -f values.yaml
# realm modelled declaratively from an imported realm JSON (IaC — gov-iac):
kubectl -n oss500-identity exec deploy/keycloak -- \
  /opt/bitnami/keycloak/bin/kcadm.sh create realms -s realm=oss500 -s enabled=true
```

Users, groups, and roles are the same primitives as Entra. **Groups** are hierarchical containers you assign roles to (Entra security groups); **realm roles** are tenant-wide (Entra directory roles), **client roles** are app-scoped (app roles). Group membership and role mappings flow into tokens as claims, which is how downstream apps make authorization decisions — so modelling groups well here is the foundation for every RBAC and conditional-access decision later.

Exam gotchas:

- The **master realm ≠ an application realm** — administering apps in master is the Keycloak equivalent of registering workloads in the tenant's admin plane; always create a dedicated realm.
- The `start-dev` H2 database and disabled HTTPS are *dev only*; a "why did all my users vanish after a restart / why are tokens rejected in prod" scenario is almost always dev-mode persistence or a mismatched hostname/issuer.
- The **issuer URL is trust-critical**: clients validate the `iss` claim against their discovery document. Change the public hostname and every existing token/client breaks — same lesson as changing an Entra tenant's federation metadata.
- Realm roles vs client roles map to Entra directory roles vs app roles; putting an app-specific permission in a realm role over-broadens it.

**Resources:**
- [Keycloak Server Administration Guide — realms, users, groups](https://www.keycloak.org/docs/latest/server_admin/index.html) (~30 min)
- [Configuring Keycloak for production](https://www.keycloak.org/server/configuration-production) (~15 min)

## Configure authentication methods, including MFA, OTP, and WebAuthn passwordless

*Objective: `kc-mfa` · OSS: Keycloak authentication flows ≈ SC-500: Entra authentication methods / MFA · Lab: [d1-keycloak-sso-mfa](../../labs/d1-keycloak-sso-mfa.md)*

Keycloak decides *how* a user proves identity through **authentication flows** — ordered trees of **executions**, each marked `REQUIRED`, `ALTERNATIVE`, `CONDITIONAL`, or `DISABLED`. The **browser flow** is the interactive login; adding an OTP or WebAuthn execution to it is exactly how you turn on MFA. This is the mechanical version of the Entra *authentication methods policy* plus a Conditional Access grant that "requires MFA": in Entra you flip a policy, in Keycloak you edit a flow, but the mental model — "which factors, required or optional, for whom" — is identical.

Second factors available out of the box:

- **OTP / TOTP** — time-based one-time passwords (FreeOTP, Google Authenticator). The `CONFIGURE_TOTP` required action forces enrolment at next login. Equivalent to the Entra Authenticator OTP method.
- **WebAuthn two-factor** — a security key or platform authenticator used *after* a password. Registered via the `webauthn-register` required action.
- **WebAuthn passwordless** — a FIDO2 key or passkey used *instead of* a password (`webauthn-register-passwordless`). This is Keycloak's phishing-resistant, passwordless path — the analogue of Entra passkeys / Windows Hello for Business. To make it a real login option you clone the browser flow, add a *Passwordless* execution as an `ALTERNATIVE` to the username/password subflow, and bind it.

```bash
# Force TOTP enrolment for everyone missing it (Entra "require MFA registration"):
kcadm.sh update realms/oss500 -s 'requiredActions[+]={"alias":"CONFIGURE_TOTP","enabled":true,"defaultAction":true}'
```

WebAuthn requires the realm's **WebAuthn Policy** (relying-party ID = your hostname, user-verification preference, attestation) to be set — the RP ID must match the public hostname or registration silently fails, the single most common WebAuthn misconfiguration.

Exam gotchas:

- **MFA lives in the flow, not on the user.** Enabling the OTP method only makes it *available*; the second factor is enforced only when an OTP/WebAuthn execution is `REQUIRED` (or `CONDITIONAL`) in the bound browser flow — the Entra parallel is "method registered" vs "Conditional Access requires it."
- **WebAuthn passwordless is the phishing-resistant option**; TOTP and Authenticator-style push are MFA but still phishable (attacker-in-the-middle relay). Match "phishing-resistant" questions to FIDO2/WebAuthn, never to OTP.
- **RP ID must equal the public hostname** — a mismatch (or plain HTTP) breaks WebAuthn registration; the Entra analogue is a broken passkey registration when the domain isn't verified.
- `CONFIGURE_TOTP` as a **required action** is the bootstrap-enrolment mechanism, the Keycloak counterpart of the Entra Temporary Access Pass / registration campaign.

**Resources:**
- [Keycloak — Configuring authentication (flows, executions, requirements)](https://www.keycloak.org/docs/latest/server_admin/index.html#configuring-authentication) (~25 min)
- [Keycloak — WebAuthn and passwordless](https://www.keycloak.org/docs/latest/server_admin/index.html#_webauthn) (~15 min)

## Implement conditional access via authentication flows and authorization policies

*Objective: `kc-ca` · OSS: Keycloak Authorization Services ≈ SC-500: Conditional Access · Lab: [d1-keycloak-conditional-access](../../labs/d1-keycloak-conditional-access.md)*

Entra Conditional Access evaluates *signals* (user/group, app, device, location/IP, risk) and returns a *grant* (allow, block, require MFA, require compliant device). Keycloak has no single "Conditional Access" blade, so you build the same if-this-then-that logic in two layers: **conditional executions in authentication flows** for the *authN-time* decision, and **Authorization Services policies** for the *authZ-time, per-resource* decision.

At authentication time, `CONDITIONAL` subflows carry **conditions** — `Condition - User Role`, `Condition - User Attribute`, `Condition - User Configured`, and (via extensions) client/IP conditions. A classic pattern: a `CONDITIONAL` subflow whose condition is "member of role `admins`" and whose action is `REQUIRED` OTP — i.e. *step-up MFA for privileged users only*, the exact shape of an Entra CA policy scoped to a directory-role group requiring MFA. You can likewise gate on a `network` attribute to approximate location conditions.

At authorization time, **Keycloak Authorization Services** turns a client into a resource server: you define **resources** (e.g. `/reports`), **scopes** (`view`, `export`), and **policies** — role-based, group-based, **time-based**, user-based, aggregate, or JavaScript — then combine them in **permissions**. The client asks Keycloak "may this subject do this scope on this resource?" and gets a decision. Time-based and attribute policies are how you express "only during business hours" or "only from a managed context" — the fine-grained, per-resource cousin of a CA grant.

```jsonc
// A time-based policy (business hours only) attached to an "export" permission
{ "type": "time", "name": "business-hours",
  "hourFrom": "9", "hour": "17", "logic": "POSITIVE" }
```

Exam gotchas:

- Split the decision by **when it happens**: flow conditions decide *at login* (get in at all / step up MFA); Authorization Services decides *per request, per resource* (may you call this scope). Entra folds both into "Conditional Access," but knowing which layer enforces what is the exam's real target.
- **Step-up MFA = a `CONDITIONAL` subflow** keyed on a role/attribute condition with a `REQUIRED` OTP/WebAuthn execution — not a global MFA toggle.
- A **break-glass equivalent** matters here too: if a condition or a mandatory factor can lock every admin out, you need an excluded account/flow — the same lesson as excluding break-glass accounts from a blocking CA policy.
- Authorization Services policies are **deny-by-default**: no matching permission means no access; over-broad JS policies are the usual "why can everyone export" bug.

**Resources:**
- [Keycloak Authorization Services Guide](https://www.keycloak.org/docs/latest/authorization_services/index.html) (~30 min)
- [Keycloak — Conditions in authentication flows](https://www.keycloak.org/docs/latest/server_admin/index.html#_conditional-flows) (~10 min)

## Configure identity for applications: OIDC clients, service accounts, and scopes

*Objective: `kc-clients` · OSS: Keycloak clients ≈ SC-500: Enterprise apps / app registrations · Lab: [d1-keycloak-sso-mfa](../../labs/d1-keycloak-sso-mfa.md)*

A Keycloak **client** is an application's identity in a realm — the merged equivalent of an Entra **app registration** (the app definition) and **enterprise application / service principal** (the per-tenant instance). Each client has a `client_id`, a protocol (OIDC or SAML), a client-authentication mode, and a set of enabled OAuth grant types (called *capability config*):

- **Confidential client** (client authentication ON) — holds a secret or keypair, uses the **authorization code** flow. This is a web app / API. Analogue: a confidential Entra app registration with a client secret/certificate.
- **Public client** (client authentication OFF) — SPAs and native apps that can't keep a secret; authorization code **with PKCE**, no client secret.
- **Bearer-only** — an API that only validates tokens and never initiates login.
- **Service account** — enabling *Service Accounts* on a confidential client gives it a hidden service-account user and the **client credentials** grant, so the app can authenticate *as itself* with no human present. This is the Keycloak equivalent of an Entra **application permission / daemon** identity (and, on the workload side, a managed identity).

```bash
# A confidential web client with standard flow + a service account (daemon identity)
kcadm.sh create clients -r oss500 \
  -s clientId=reports-api -s protocol=openid-connect \
  -s publicClient=false -s standardFlowEnabled=true \
  -s serviceAccountsEnabled=true \
  -s 'redirectUris=["https://reports.oss500.local/*"]'
```

**Redirect URIs** must be exact (wildcards only where the docs allow) — a permissive `*` redirect is a token-theft foothold, the same finding as an over-broad Entra reply URL. Roles the client needs are granted to its **service-account user** via role mappings, and what ends up in its tokens is governed by **client scopes** and protocol mappers (see `kc-consent`).

Exam gotchas:

- **Client authentication ON = confidential** (has a secret, can use client credentials); **OFF = public** (SPA/native, PKCE, never a secret). Putting a secret in a SPA is the classic error — mirrors "don't use a client secret in a public client" in Entra.
- **Service accounts use the client-credentials grant** and are the app-as-itself (daemon) identity; their permissions come from role mappings on the service-account user, and, like Entra application permissions, they aren't a human's delegated access.
- **Standard flow = authorization code**; enable **PKCE** for public clients. *Direct access grants* (resource-owner password) and *implicit* flow are legacy — enabling them needlessly is an audit finding, just like enabling ROPC/implicit on an Entra app.
- Registration vs instance: Keycloak fuses them into one *client* object, but the exam still tests the Entra distinction (app registration = global definition, service principal = per-tenant instance carrying SSO/assignment/consent).

**Resources:**
- [Keycloak — Managing OIDC clients](https://www.keycloak.org/docs/latest/server_admin/index.html#_oidc_clients) (~20 min)
- [Keycloak — Service accounts](https://www.keycloak.org/docs/latest/server_admin/index.html#_service_accounts) (~10 min)

## Configure identity federation and brokering across SAML/OIDC providers

*Objective: `kc-federation` · OSS: Keycloak identity brokering ≈ SC-500: Entra external identities / federation · Lab: [d1-keycloak-conditional-access](../../labs/d1-keycloak-conditional-access.md)*

**Identity brokering** lets Keycloak delegate authentication to an *external* IdP — another Keycloak, an Entra tenant, Google, GitHub, or any OIDC/SAML provider — while still issuing *its own* tokens to your apps. This is the pattern behind Entra **external identities / B2B federation** and **federated SAML/WS-Fed**: your apps trust one issuer (Keycloak), and Keycloak in turn trusts one or more upstream providers. Distinguish it from **user federation** (LDAP/Kerberos), which imports an existing *user store* rather than delegating the login.

You add an **Identity Provider** in the realm (e.g. an OIDC provider pointed at the partner's discovery URL, or a SAML provider fed the partner's metadata). On first login through a broker, Keycloak runs the **First Login Flow** to link or create the local user, and **identity-provider mappers** translate incoming claims/assertions (email, groups, roles) into local user attributes and role mappings — the same job as Entra claims mapping / attribute mapping for a federated IdP.

```bash
# Broker to an upstream OIDC provider (e.g. a partner Entra tenant or another Keycloak)
kcadm.sh create identity-provider/instances -r oss500 \
  -s alias=partner-oidc -s providerId=oidc -s enabled=true \
  -s 'config.authorizationUrl=https://partner.example/authorize' \
  -s 'config.tokenUrl=https://partner.example/token' \
  -s 'config.clientId=oss500-broker' -s 'config.clientSecret=REDACTED'
```

For SAML you exchange **metadata** (Keycloak exposes its SP metadata at `/realms/oss500/broker/<alias>/endpoint/descriptor` and consumes the IdP's), validate **signatures** on assertions, and map the `NameID`. Trust is only as strong as signature validation and the mapper scope — accepting unsigned assertions or blindly mapping an upstream `groups` claim into privileged local roles is the federation-equivalent of an over-trusting Entra claims transformation.

Exam gotchas:

- **Brokering (delegate authN to an external IdP) ≠ user federation (import an LDAP/Kerberos user store).** Both "federate," but a "log in with the partner's Entra/Google account" scenario is brokering; "authenticate against corporate Active Directory" is user federation.
- **First Login Flow + IdP mappers** control account linking and what upstream claims become — the security-critical step. An attacker-controlled upstream claim mapped into an admin role is a real escalation path.
- SAML trust hinges on **signed assertions and correct metadata/certs**; a "federation configured but logins rejected / assertions untrusted" scenario is usually a signing-cert or entity-ID/ACS-URL mismatch — the same class as broken Entra SAML federation metadata.
- Keycloak issues its *own* tokens after brokering; downstream apps never see the upstream token — the isolation that makes brokering safe, and why apps only trust one issuer.

**Resources:**
- [Keycloak — Identity brokering](https://www.keycloak.org/docs/latest/server_admin/index.html#_identity_broker) (~25 min)
- [Keycloak — Integrating identity providers (OIDC/SAML)](https://www.keycloak.org/docs/latest/server_admin/index.html#_general-idp-config) (~15 min)

## Manage OAuth scopes, client scopes, and consent

*Objective: `kc-consent` · OSS: Keycloak client scopes / consent ≈ SC-500: OAuth permission grants and consent · Lab: [d1-keycloak-conditional-access](../../labs/d1-keycloak-conditional-access.md)*

OAuth **scopes** are the permissions an app requests; **consent** is the recorded agreement that a user (or admin) granted them. Keycloak packages scopes as **client scopes** — reusable bundles of protocol mappers and role scope-mappings — attached to a client as **Default** (always in the token) or **Optional** (only when the client requests them via the `scope` parameter). This is the direct analogue of Entra **delegated permissions/scopes**, and the Default/Optional split maps to always-granted vs requested-at-runtime permissions.

**Consent** is controlled per client with the **Consent Required** toggle. With it on, the first time a user authenticates to the client Keycloak shows a consent screen listing each client scope's **Consent Screen Text**, and records the grant — visible and revocable by the user in the Account Console (*Applications / Device Activity*) and by admins per user. This is the Keycloak version of the Entra user-consent experience and of admins reviewing/revoking **OAuth permission grants** after an illicit-consent (consent-phishing) attack.

```bash
# An optional client scope the app must explicitly request; consent-visible
kcadm.sh create client-scopes -r oss500 \
  -s name=reports:export -s protocol=openid-connect \
  -s 'attributes."display.on.consent.screen"=true' \
  -s 'attributes."consent.screen.text"=Export report data'
```

The governance question the exam cares about is *who is allowed to consent to what*. Turning Consent Required off for a first-party app is fine; leaving it off for third-party clients means users grant broad scopes with no prompt — the illicit-consent risk. The Keycloak hardening posture mirrors Entra's recommended stance: require consent for non-first-party clients, keep client scopes least-privilege (don't dump everything into Default), and audit recorded consents to catch over-granted or malicious apps.

Exam gotchas:

- **Default vs Optional client scopes** = always-in-token vs requested-at-runtime — the Entra always-granted vs runtime-requested delegated-permission distinction. Over-stuffing Default scopes over-broadens every token the client gets.
- **Consent Required is per client.** First-party apps typically skip consent; third-party apps should require it. A consent-phishing / illicit-grant scenario is answered by requiring consent, least-privilege client scopes, and **revoking the recorded grant** — the same playbook as revoking an Entra OAuth permission grant.
- Consent grants are **recorded and revocable** (Account Console / admin per-user) — the audit surface for "which apps did this user authorize," the Keycloak counterpart to reviewing enterprise-app permissions.
- Scope ≠ role: a client scope can carry **role scope-mappings** that *narrow* which of the user's roles appear in the token (`Full Scope Allowed` off) — leaving Full Scope Allowed on is a common over-permission finding.

**Resources:**
- [Keycloak — Client scopes and protocol mappers](https://www.keycloak.org/docs/latest/server_admin/index.html#_client_scopes) (~20 min)
- [Keycloak — Managing consent for clients](https://www.keycloak.org/docs/latest/server_admin/index.html#_consent) (~10 min)

## Summary

| Objective | Takeaway |
|---|---|
| `kc-deploy` | Realm = Entra tenant; master realm is admin-only; Postgres + fixed hostname/issuer for prod; groups/realm-roles/client-roles model identity |
| `kc-mfa` | MFA is enforced in the *authentication flow* (REQUIRED/CONDITIONAL execution), not on the user; WebAuthn passwordless = phishing-resistant, TOTP is not; RP ID must match hostname |
| `kc-ca` | Conditional access = flow conditions (login-time, step-up MFA) + Authorization Services policies (per-resource, deny-by-default); split by *when* the decision happens |
| `kc-clients` | Confidential (secret, code flow, service accounts/client-credentials) vs public (PKCE, no secret); exact redirect URIs; service account = daemon/app identity |
| `kc-federation` | Brokering delegates authN to an external OIDC/SAML IdP (Keycloak still issues its own tokens); ≠ LDAP user federation; First Login Flow + mappers are the trust-critical step |
| `kc-consent` | Client scopes Default vs Optional; Consent Required per client; require consent for third-party apps, least-privilege scopes, revoke illicit grants; Full Scope Allowed off |
