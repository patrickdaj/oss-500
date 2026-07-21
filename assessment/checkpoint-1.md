# Checkpoint 1 — Identity, access, and governance

Generated from `assessment/data/quiz-1.yaml` — study-hub runs this interactively (Tests page). Pass bar: 80%. 28 questions.

### 1. A teammate stood up Keycloak with `kc.sh start-dev`, created users in the built-in master realm, and pointed the production web app at it. After a pod restart all users vanished and tokens are now rejected. Which two root causes best explain this, and what is the correct production setup?

- A. Keycloak requires a paid license for persistence; buy the enterprise tier
- B. start-dev uses the ephemeral H2 database (state lost on restart) and workloads were modelled in the master realm; run `start` with Postgres, a fixed hostname/issuer, and a dedicated application realm
- C. The master realm cannot hold users; move them to a client scope
- D. Tokens were rejected because MFA was not enabled on the realm

<details><summary>Answer</summary>

**B** — `start-dev` uses the in-memory/H2 dev database and disables HTTPS/hostname checks, so state is lost on restart and the issuer is unstable. The master realm is for administering other realms — application identities belong in a dedicated realm (the Entra-tenant analogue). Production needs `kc.sh start` with Postgres and a fixed hostname so the issuer in every token stays stable.

[Documentation](https://www.keycloak.org/server/configuration-production) · objectives: `kc-deploy`

</details>

### 2. You are modelling identities in Keycloak to mirror an Entra tenant. A permission is specific to one application (the reports API) and should not appear on unrelated apps. Which construct fits, and what is its Entra analogue?

- A. A realm role — the analogue of an Entra directory role
- B. A client role on the reports-api client — the analogue of an Entra app role
- C. A default client scope applied to every client
- D. A group in the master realm

<details><summary>Answer</summary>

**B** — Client roles are scoped to a single client, the Keycloak equivalent of an Entra app role; realm roles are tenant-wide (directory-role analogue). Putting an app-specific permission in a realm role over-broadens it, and the master realm is admin-only.

[Documentation](https://www.keycloak.org/docs/latest/server_admin/index.html#assigning-permissions-using-roles-and-groups) · objectives: `kc-deploy`

</details>

### 3. You enabled the OTP authentication method in the Keycloak realm, but users still sign in with a password only and are never prompted for a second factor. What is missing?

- A. Users must each buy a hardware token before OTP works
- B. An OTP execution must be added to the bound browser flow as REQUIRED (or CONDITIONAL); enabling the method only makes it available, it does not enforce it
- C. OTP only works if the realm is switched to passwordless mode
- D. The realm needs a paid MFA add-on

<details><summary>Answer</summary>

**B** — MFA is enforced in the authentication flow, not by enabling the method. The second factor is required only when an OTP/WebAuthn execution is REQUIRED or CONDITIONAL in the bound browser flow — exactly the Entra distinction between a registered method and a Conditional Access policy that requires it.

[Documentation](https://www.keycloak.org/docs/latest/server_admin/index.html#configuring-authentication) · objectives: `kc-mfa`

</details>

### 4. Security mandates phishing-resistant authentication for realm administrators in Keycloak. Which options satisfy that requirement? (Select two)

- A. TOTP one-time passwords from an authenticator app
- B. WebAuthn passwordless with a FIDO2 security key / passkey
- C. WebAuthn two-factor with a platform authenticator after a password
- D. SMS one-time passcodes

<details><summary>Answer</summary>

**B, C** (multiple answers) — FIDO2/WebAuthn (passwordless or two-factor) is origin-bound and phishing-resistant. TOTP and SMS are MFA but remain phishable via attacker-in-the-middle relay — the same reason Entra treats passkeys / Windows Hello as phishing-resistant and OTP/SMS as not.

[Documentation](https://www.keycloak.org/docs/latest/server_admin/index.html#_webauthn) · objectives: `kc-mfa`

</details>

### 5. You want users with the `admins` role to be forced through MFA at login, while regular users are not. In Keycloak, how do you build this conditional-access behaviour?

- A. Set a global realm toggle 'require MFA for all'
- B. Add a CONDITIONAL subflow whose condition is 'user has role admins' containing a REQUIRED OTP/WebAuthn execution
- C. Create an Authorization Services time-based policy
- D. Enable Consent Required on every client

<details><summary>Answer</summary>

**B** — Step-up MFA is a CONDITIONAL subflow keyed on a role condition with a REQUIRED second-factor execution — the flow-level (login-time) decision, the shape of an Entra CA policy scoped to a role group requiring MFA. A global toggle would hit everyone; Authorization Services governs per-resource access, not login-time step-up.

[Documentation](https://www.keycloak.org/docs/latest/server_admin/index.html#_conditional-flows) · objectives: `kc-ca`

</details>

### 6. A client uses Keycloak Authorization Services. A resource `/reports` has a `view` permission bound to a role policy, but no permission references the `export` scope. A user with every role calls `export`. What happens and why?

- A. Allowed — users with all roles bypass Authorization Services
- B. Denied — Authorization Services is deny-by-default; a scope with no matching permission is not granted
- C. Allowed — undefined scopes default to permit
- D. Denied — only because the user lacks the view permission

<details><summary>Answer</summary>

**B** — Authorization Services evaluates deny-by-default: a request for a scope with no permission granting it is denied regardless of the caller's roles. This is the per-resource, per-scope authorization layer (distinct from the login-time flow decision).

[Documentation](https://www.keycloak.org/docs/latest/authorization_services/index.html) · objectives: `kc-ca`

</details>

### 7. A single-page application (SPA) running entirely in the browser needs to authenticate users against Keycloak. How should its client be configured?

- A. Confidential client with a client secret embedded in the JavaScript bundle
- B. Public client using the authorization code flow with PKCE and no client secret
- C. Bearer-only client
- D. A service account using the client-credentials grant

<details><summary>Answer</summary>

**B** — A browser SPA cannot keep a secret, so it must be a public client using authorization code with PKCE — never a confidential client with an embedded secret. Bearer-only is for APIs that only validate tokens; client-credentials is for daemon (no-user) identities.

[Documentation](https://www.keycloak.org/docs/latest/server_admin/index.html#_oidc_clients) · objectives: `kc-clients`

</details>

### 8. A nightly batch job with no interactive user must authenticate to an API as itself. In Keycloak, what gives the job an identity and which grant does it use?

- A. A public client with the implicit flow
- B. A confidential client with Service Accounts enabled, using the client-credentials grant; roles are granted to its service-account user
- C. The resource-owner password grant with a shared service password
- D. A bearer-only client with direct access grants

<details><summary>Answer</summary>

**B** — Enabling Service Accounts on a confidential client creates a hidden service-account user and the client-credentials grant, so the app authenticates as itself with no human present — the Keycloak equivalent of an Entra application (daemon) identity / managed identity. Its permissions come from role mappings on the service-account user.

[Documentation](https://www.keycloak.org/docs/latest/server_admin/index.html#_service_accounts) · objectives: `kc-clients`

</details>

### 9. Partner-company users must sign in to your app using their own Entra tenant, but your app should keep trusting only one issuer (your Keycloak). Which Keycloak capability fits, and how is it different from user federation?

- A. User federation via LDAP — import the partner's directory
- B. Identity brokering — add the partner as an OIDC/SAML identity provider; Keycloak delegates authentication upstream but still issues its own tokens. User federation instead imports an external user store (LDAP/Kerberos)
- C. Create local accounts for every partner user
- D. Enable Consent Required on the partner client

<details><summary>Answer</summary>

**B** — Delegating login to an external IdP while issuing your own tokens is identity brokering (the Entra B2B/federation analogue). User federation is a different feature that imports an LDAP/Kerberos user store. The First Login Flow and IdP mappers control account linking and claim mapping.

[Documentation](https://www.keycloak.org/docs/latest/server_admin/index.html#_identity_broker) · objectives: `kc-federation`

</details>

### 10. After a consent-phishing incident, users had granted a malicious third-party Keycloak client broad scopes. What is the correct hardening and remediation posture?

- A. Disable all clients permanently
- B. Require consent (Consent Required) for third-party clients, keep client scopes least-privilege (avoid stuffing Default scopes), and revoke the recorded consent grants
- C. Move every scope into Default client scopes so nothing is requested at runtime
- D. Turn on implicit flow so tokens expire faster

<details><summary>Answer</summary>

**B** — The illicit-consent playbook mirrors Entra: require consent for non-first-party clients, keep scopes least-privilege, and revoke the recorded grants (visible/revocable in the Account Console or by an admin). Stuffing Default scopes over-broadens every token; implicit flow is unrelated and legacy.

[Documentation](https://www.keycloak.org/docs/latest/server_admin/index.html#_consent) · objectives: `kc-consent`

</details>

### 11. A security review flags a pod carrying a non-expiring, auto-generated Secret-based ServiceAccount token. What is the modern, correct token delivery, and why is it safer?

- A. Base64-encode the Secret token so it is encrypted
- B. Use a bound, projected ServiceAccount token (TokenRequest API): audience-scoped, time-limited, kubelet-rotated, and bound to the pod lifecycle
- C. Store the token in a ConfigMap instead of a Secret
- D. Grant the pod cluster-admin so it does not need a token

<details><summary>Answer</summary>

**B** — Since 1.22 pods should receive bound projected tokens via the TokenRequest API — audience-scoped, short-lived, auto-rotated, and invalid once the pod is gone. The legacy non-expiring Secret token is exactly the long-lived credential you want eliminated, the same value proposition as a managed identity over a stored secret.

[Documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#serviceaccount-token-volume-projection) · objectives: `wi-sa`

</details>

### 12. Most pods in a namespace never call the Kubernetes API, yet each mounts a ServiceAccount token an attacker could exfiltrate. What is the least-privilege baseline?

- A. Delete the default ServiceAccount from the namespace
- B. Set `automountServiceAccountToken: false` (on the SA or per pod) and opt in only where a workload actually needs API access
- C. Give every pod a unique cluster-admin token
- D. Move all tokens into a shared Secret

<details><summary>Answer</summary>

**B** — Default-deny the token by setting automountServiceAccountToken: false and opting in only for workloads that call the API — the Kubernetes echo of not attaching a credential a workload does not need. Deleting the default SA breaks pods that reference it; cluster-admin is the opposite of least privilege.

[Documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) · objectives: `wi-sa`

</details>

### 13. You want HashiCorp Vault to trust Kubernetes workloads without any shared secret, validating tokens offline. Which cluster capability makes this possible?

- A. The cluster's base64 Secret encoding
- B. The cluster OIDC issuer: its discovery document and JWKS let a relying party validate a ServiceAccount token's signature offline against `iss`, `sub`, `aud`, and expiry
- C. A shared kubeconfig copied into Vault
- D. The pod's IP allowlist

<details><summary>Answer</summary>

**B** — The API server is an OIDC issuer publishing discovery + JWKS, so any relying party can validate a projected token cryptographically and offline — the open-source form of workload identity federation (no stored secret). Vault JWT auth and cloud federation use JWKS; Vault's kubernetes auth instead validates online via TokenReview.

[Documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#service-account-issuer-discovery) · objectives: `wi-oidc`

</details>

### 14. A Vault JWT role is configured to trust the cluster issuer but binds on no specific subject or audience. Why is this dangerous?

- A. It is fine; trusting the issuer is sufficient
- B. Any ServiceAccount token from that issuer would satisfy the role, so any pod could assume the role — federation must bind on the exact `sub` (system:serviceaccount:ns:name) and `aud`
- C. Vault will reject all tokens without a shared secret
- D. It only affects tokens older than one hour

<details><summary>Answer</summary>

**B** — Trusting the issuer alone (or a wildcard subject) lets every workload assume the role — a real privilege-escalation path and the analogue of a federated credential whose subject filter matches too much. Always bind on the exact subject and audience.

[Documentation](https://developer.hashicorp.com/vault/docs/auth/jwt) · objectives: `wi-oidc`

</details>

### 15. Two services in different clusters must mutually authenticate with mTLS using a portable, platform-agnostic identity and no shared secret. Which technology fits, and what proves a workload's identity before it gets a credential?

- A. Kubernetes Secret tokens; the API server proves identity
- B. SPIFFE/SPIRE: each workload gets a SPIFFE ID in a short-lived SVID; the SPIRE agent performs node attestation then workload attestation (selectors) before issuing the SVID
- C. A shared client secret distributed to both services
- D. An NGINX basic-auth password

<details><summary>Answer</summary>

**B** — SPIFFE defines the identity (SPIFFE ID + SVID) and SPIRE issues/rotates SVIDs after node attestation and workload attestation — attestation, not a shared secret, is the trust root. This is the mTLS service-identity substrate a mesh uses, the closest analogue to managed identities for services generalized across platforms.

[Documentation](https://spiffe.io/docs/latest/spiffe-about/overview/) · objectives: `wi-spiffe`

</details>

### 16. Security wants to eliminate standing SSH keys on production hosts and make privileged access time-bound. Using Teleport, which mechanism enforces the just-in-time window?

- A. A shared bastion host with a permanent admin key
- B. Short-lived certificates issued at `tsh login` with a role `max_session_ttl`; access ends automatically when the certificate expires, and the resources are only reachable through the proxy
- C. A static kubeconfig distributed to each engineer
- D. A firewall rule that opens SSH during business hours

<details><summary>Answer</summary>

**B** — Teleport is an identity-aware proxy issuing short-lived certs whose TTL is the JIT window — access dies on expiry, not on someone remembering to revoke it (the PIM activation-window analogue). The property depends on the hosts being reachable only through the proxy; a leftover direct SSH path defeats it.

[Documentation](https://goteleport.com/docs/admin-guides/access-controls/guides/role-templates/) · objectives: `pam-jit`

</details>

### 17. You must ensure privileged-session evidence survives even if the target host is fully compromised, and that recordings cannot be deleted before they are stored. Which Teleport setting is correct?

- A. session_recording: node — record on the target host
- B. session_recording: proxy-sync — record at the proxy (off the administered host) and stream directly to storage
- C. Disable recording to reduce attack surface
- D. Rely only on the structured audit events; recordings are unnecessary

<details><summary>Answer</summary>

**B** — Proxy-side recording keeps the evidence off the host being administered, so a compromised target cannot tamper with it; the -sync variant streams straight to storage with no local buffer to delete first. Node recording is cheaper but tamperable. Audit events (structured who/what) are complementary but are not the replayable session.

[Documentation](https://goteleport.com/docs/reference/architecture/session-recording/) · objectives: `pam-session`

</details>

### 18. An engineer holds a baseline Teleport role that is allowed to *request* the `db-admin` role but carries none of its permissions. During an incident they run `tsh request create --roles=db-admin`. What is true until a reviewer approves, and what enforces separation of duties?

- A. They already have db-admin; the request is only for logging
- B. They have no db-admin permissions until an approver acts; the reviewer must hold review authority (review_requests.roles), which is separate from the request permission so users cannot approve their own escalation
- C. The request auto-approves after 5 minutes
- D. Approval grants permanent db-admin

<details><summary>Answer</summary>

**B** — A requestable role is eligible-not-active — it grants nothing until an approved request re-issues the certificate with the role for a bounded window (the PIM eligible+approval model). Request and review are distinct role permissions, enforcing separation of duties; approval is time-boxed and audited, never permanent.

[Documentation](https://goteleport.com/docs/admin-guides/access-controls/access-requests/) · objectives: `pam-approval`

</details>

### 19. A ServiceAccount in `oss500-apps` unexpectedly can read secrets in *every* namespace, though you only wrote one namespaced Role for it. What most likely happened?

- A. Roles are cluster-wide by default
- B. A ClusterRole granting secret read was attached with a ClusterRoleBinding (cluster-wide) instead of a namespaced RoleBinding — the binding, not the role, sets the scope
- C. Kubernetes RBAC has an implicit allow-all rule
- D. The Role inherited permissions from the default ServiceAccount

<details><summary>Answer</summary>

**B** — Scope is decided by the binding: a ClusterRole bound by a ClusterRoleBinding applies cluster-wide, whereas a RoleBinding would limit it to one namespace. This is the classic 'why can this subject act everywhere' bug and the direct parallel of choosing an Azure role-assignment scope.

[Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) · objectives: `rbac-roles`

</details>

### 20. You need a subject to read pods in exactly one namespace and nothing else. Which is the least-privilege construction?

- A. Bind the built-in `view` ClusterRole with a ClusterRoleBinding
- B. Create a namespaced Role with get/list/watch on pods and attach it with a RoleBinding in that namespace
- C. Grant `edit` in the namespace
- D. Add a deny rule for all other namespaces

<details><summary>Answer</summary>

**B** — Least privilege means narrow verbs, narrow resources, and narrow scope: a namespaced Role (get/list/watch on pods) bound by a RoleBinding in the one namespace. A ClusterRoleBinding would grant cluster-wide read; `edit` is too broad; and RBAC has no deny rules — you restrict by not granting.

[Documentation](https://kubernetes.io/docs/concepts/security/rbac-good-practices/) · objectives: `rbac-roles`, `rbac-least`

</details>

### 21. A namespace contains a highly privileged ServiceAccount. An auditor warns that a developer with only `create` on pods in that namespace can effectively escalate. How?

- A. They cannot; create on pods is harmless
- B. A pod can be scheduled with any ServiceAccount in the namespace and mount its token, so 'create pods' implicitly grants that privileged SA's powers
- C. Creating a pod grants cluster-admin automatically
- D. The developer would need the impersonate verb as well

<details><summary>Answer</summary>

**B** — Because a pod can run as any SA in its namespace and mount that SA's token, the ability to create pods implicitly confers the powers of the most privileged SA available — an escalation path. Keep privileged ServiceAccounts out of namespaces where many subjects can create pods.

[Documentation](https://kubernetes.io/docs/concepts/security/rbac-good-practices/) · objectives: `rbac-least`

</details>

### 22. Which Kubernetes RBAC verbs let a subject exceed its own nominal permissions and should be granted only very deliberately? (Select two)

- A. get
- B. impersonate
- C. escalate
- D. watch

<details><summary>Answer</summary>

**B, C** (multiple answers) — `impersonate` lets a subject act as any user/group/SA (kubectl --as), bypassing its own limits, and `escalate`/`bind` on roles let a subject grant itself permissions it does not hold. get/watch are ordinary read verbs. These escalation primitives are the usual answer to 'user has role X but can become admin.'

[Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#privilege-escalation-prevention-and-bootstrapping) · objectives: `rbac-least`

</details>

### 23. During an access review you must answer 'who can read Secrets in the oss500-apps namespace?' across many Roles and bindings. Which is the most direct approach?

- A. Read every RoleBinding YAML by hand and guess the union
- B. Run `kubectl who-can list secrets -n oss500-apps` (or `rbac-tool who-can`) — the forward query that computes the effective set of subjects
- C. Delete all bindings and re-add the ones you remember
- D. Check the Deny rules for Secrets

<details><summary>Answer</summary>

**B** — Because RBAC is additive and spread across objects, effective permissions are the union of all bound roles; who-can tooling computes the forward answer ('who can do X') directly — the access-review analogue. There are no deny rules to check, and manual guessing misses aggregated grants.

[Documentation](https://github.com/aquasecurity/kubectl-who-can) · objectives: `rbac-audit`

</details>

### 24. With OPA Gatekeeper you wrote a ConstraintTemplate requiring an `owner` label but no resources are being blocked. What is missing, and how does this map to Azure Policy?

- A. Nothing — templates enforce on their own
- B. A Constraint (an instance of the template) that sets the match scope and `enforcementAction: deny` must exist; the template is the policy definition and the Constraint is the scoped assignment — the Azure Policy definition vs assignment split
- C. You must switch Gatekeeper to Kyverno mode
- D. The template needs `enforcementAction: audit` to deny

<details><summary>Answer</summary>

**B** — Gatekeeper separates the ConstraintTemplate (definition + Rego) from the Constraint (which sets where it applies and how hard). A template with no Constraint enforces nothing — the same definition-vs-assignment model as Azure Policy (which for AKS is built on Gatekeeper). deny blocks; audit only reports.

[Documentation](https://open-policy-agent.github.io/gatekeeper/website/docs/howto/) · objectives: `gov-gatekeeper`

</details>

### 25. You want pods that omit a securityContext to be automatically given `runAsNonRoot: true` at admission rather than simply rejected. Which Kyverno rule type does this, and what Azure Policy effect is it like?

- A. A validate rule with validationFailureAction: Enforce
- B. A mutate rule that patches the resource on admission — the analogue of an Azure Policy Modify effect (remediation, not just detection)
- C. A generate rule that creates a new namespace
- D. A verifyImages rule checking cosign signatures

<details><summary>Answer</summary>

**B** — Kyverno mutate rules patch resources as they are admitted (inject a secure default), the remediation capability that maps to Azure Policy's Modify effect. validate only allows/denies, generate provisions companion resources, and verifyImages enforces signatures.

[Documentation](https://kyverno.io/docs/writing-policies/mutate/) · objectives: `gov-kyverno`

</details>

### 26. Leadership wants a periodic score of how the cluster measures up to the NSA-CISA Kubernetes hardening guidance, with per-control pass/fail and remediation. Which tool and what is the key caveat?

- A. Kyverno in Enforce mode — it produces a compliance certificate
- B. Kubescape `scan framework nsa` — it measures and scores posture against the framework (a Defender secure-score analogue); a passing score is technical-control coverage, not a formal certification
- C. OPA Gatekeeper audit — it blocks non-compliant frameworks
- D. kubectl auth can-i --list

<details><summary>Answer</summary>

**B** — Kubescape scores the estate against frameworks like NSA-CISA/CIS/MITRE with severity-weighted controls — the secure-score/regulatory-compliance analogue, and detective (measuring) rather than preventive (admission enforcement). As with Defender's dashboard, a passing score is not the same as being certified compliant.

[Documentation](https://kubescape.io/docs/frameworks-and-controls/) · objectives: `gov-compliance`

</details>

### 27. Your team wants security controls (namespaces, RBAC, admission policies) to be reviewable before they go live and catchable in CI before deploy. Which practices deliver this 'security via IaC' outcome?

- A. Configure everything by clicking through a dashboard so it is quick
- B. Keep controls as version-controlled Helm/manifests, use `helm template` to render-and-review before apply, and shift-left scan the manifests in CI with Kubescape/Trivy
- C. Apply controls imperatively with one-off kubectl edit commands
- D. Store the manifests only on the operator's laptop

<details><summary>Answer</summary>

**B** — IaC makes controls reviewable (diff/`helm template`), reproducible, versioned, and testable, and shift-left scanning catches misconfigurations before deployment — the open-source form of scanning IaC/DevOps templates. Policy-as-code (Gatekeeper/Kyverno objects in git) is itself IaC.

[Documentation](https://kubescape.io/docs/scanning/scan-yaml/) · objectives: `gov-iac`

</details>

### 28. You must introduce a new admission policy across a busy cluster without breaking existing deployments on day one, then enforce it later. What is the correct rollout for Gatekeeper and Kyverno respectively?

- A. Start with deny/Enforce immediately to be safe
- B. Start with Gatekeeper `enforcementAction: dryrun` (or warn) and Kyverno `validationFailureAction: Audit` to observe violations, then switch to deny/Enforce — the Azure Policy Audit-then-Deny pattern
- C. Delete non-compliant resources first, then add the policy
- D. Use compliance scanning instead of any admission policy

<details><summary>Answer</summary>

**B** — Roll out with the report-only modes (Gatekeeper dryrun/warn, Kyverno Audit) to surface violations against real traffic and existing resources without blocking, then flip to deny/Enforce — exactly the Azure Policy Audit-before-Deny rollout. Both engines report existing violations without deleting anything.

[Documentation](https://open-policy-agent.github.io/gatekeeper/website/docs/audit/) · objectives: `gov-gatekeeper`, `gov-kyverno`

</details>
