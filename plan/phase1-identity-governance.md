# Phase 1 — Identity, access, governance

Domain 1 is **20–25%** of SC-500 — the largest single share after secrets/data — and it is the foundation every later domain leans on (workloads need identities, monitoring needs subjects to attribute events to). This phase teaches the whole domain on open source: Keycloak as the identity provider, Kubernetes ServiceAccounts + SPIFFE for workload identity, Teleport for privileged access, Kubernetes RBAC, and Kyverno/Gatekeeper/Kubescape for governance. **Milestone (end of phase):** every Domain 1 objective green in the tracker, its lab performed (or walkthrough studied), and **Checkpoint 1 ≥ 80%**.

Bring up only the component the current day needs (`lab-infra/identity`, `lab-infra/pam`, `lab-infra/governance`); the RBAC and workload-identity labs run on the bare kind cluster. Tear each component down at the end of its block — Keycloak and Teleport don't need to survive past their labs. Reference host: ~4 CPU / 16 GB / 40 GB (see [lab-infra/README](../lab-infra/README.md)).

## Day 1 — Identity provider: deploy, clients, MFA

- [ ] **[2h] Read — the IdP model** — [domains/1-identity-governance/identity-provider.md](../domains/1-identity-governance/identity-provider.md) sections `kc-deploy`, `kc-clients`, `kc-mfa`. Anchor the mapping: realm = Entra tenant, client = app registration + service principal, authentication flow = where MFA is actually enforced. *(input)*
- [ ] **[2h] Lab — Keycloak SSO & MFA** — [labs/d1-keycloak-sso-mfa.md](../labs/d1-keycloak-sso-mfa.md): `cd lab-infra/identity && cp admin-password.env.example admin-password.env && ./up.sh`, model the `oss500` realm/users/groups, create a confidential OIDC client + a service account, then enable TOTP and WebAuthn passwordless. *(output)*
- [ ] **[1h] Prove the control** — watch an OTP challenge appear at login; issue a client-credentials JWT from the service account with `curl`; confirm a public client is rejected when it presents a secret. Leave `lab-infra/identity` up — Day 2 continues on it.
- [ ] **[1h] Quiz drill** — attempt the `kc-deploy`, `kc-clients`, `kc-mfa` questions in [assessment/data/quiz-1.yaml](../assessment/data/quiz-1.yaml); note anything you missed for the flex day. *(output)*

## Day 2 — Conditional access, federation, consent

- [ ] **[1.5h] Read — CA, brokering, consent** — [identity-provider.md](../domains/1-identity-governance/identity-provider.md) sections `kc-ca`, `kc-federation`, `kc-consent`. Split the conditional-access decision by *when* it happens: flow conditions (login-time step-up) vs Authorization Services (per-resource, deny-by-default). *(input)*
- [ ] **[2.5h] Lab — Conditional access, federation & consent** — [labs/d1-keycloak-conditional-access.md](../labs/d1-keycloak-conditional-access.md): build a CONDITIONAL subflow that steps up MFA for `admins` only, broker to an upstream OIDC provider, and turn on Consent Required with an optional client scope. *(output)*
- [ ] **[1h] Prove the control** — an admin login triggers OTP step-up while a normal user does not; a brokered login round-trips and Keycloak issues its *own* token; the consent screen lists the scope and the grant is revocable in the Account Console.
- [ ] **[1h] Teardown + notes** — `cd lab-infra/identity && ./down.sh`; confirm no leftovers (`kubectl get all -A -l app.kubernetes.io/part-of=oss500`). Jot the brokering-vs-user-federation and Default-vs-Optional-scope distinctions in your own words. *(output)*

## Day 3 — Workload identity

- [ ] **[2h] Read — workload identity** — [domains/1-identity-governance/workload-identity.md](../domains/1-identity-governance/workload-identity.md), all three objectives. Understand bound projected tokens (`aud`/`exp`/`sub`), the cluster OIDC issuer, and where SPIFFE/SPIRE fits. *(input)*
- [ ] **[2h] Lab — Workload identity** — [labs/d1-workload-identity.md](../labs/d1-workload-identity.md) on the bare kind cluster: create a ServiceAccount with `automountServiceAccountToken: false`, mount an audience-scoped projected token, decode it, and inspect the cluster's `/.well-known/openid-configuration` + JWKS. Study the SPIFFE/SPIRE section as a **walkthrough**. *(output)*
- [ ] **[1h] Prove the control** — a decoded token shows a short `exp`, the intended `aud`, and `sub=system:serviceaccount:oss500-apps:reports`; a default-SA pod has no token mounted; a wrong-audience TokenReview is rejected. Clean up the demo SA/pods (base cluster stays).
- [ ] **[1h] Quiz + connect** — answer the `wi-sa`, `wi-oidc`, `wi-spiffe` questions; note how this token becomes the trust anchor Vault reuses in Phase 2 (`vault-k8s`). *(output)*

## Day 4 — Privileged access management

- [ ] **[2h] Read — PAM** — [domains/1-identity-governance/privileged-access.md](../domains/1-identity-governance/privileged-access.md). Map PIM onto Teleport: short-lived certs = time-boxed activation, access requests = eligible+approval, session recording = audit. *(input)*
- [ ] **[2h] Lab — Privileged access with Teleport** — [labs/d1-privileged-access.md](../labs/d1-privileged-access.md): `cd lab-infra/pam && ./up.sh`, `tsh login`, inspect the certificate TTL, start and replay a recorded session, and study the access-request **approval walkthrough** (request → review → time-boxed elevation). *(output)*
- [ ] **[1h] Prove the control** — `tsh status` shows a short-lived cert that expires; `tsh play` replays a recorded session; an access request sits PENDING then APPROVED and the elevated role appears only after approval. `cd lab-infra/pam && ./down.sh`.
- [ ] **[1h] Quiz drill** — `pam-jit`, `pam-session`, `pam-approval` questions; capture the proxy-side-recording and separation-of-duties points. *(output)*

## Day 5 — Cluster RBAC and governance

- [ ] **[2h] Read — RBAC + governance** — [kubernetes-rbac.md](../domains/1-identity-governance/kubernetes-rbac.md) and [governance.md](../domains/1-identity-governance/governance.md). Key anchors: the binding sets the scope; RBAC is additive/no-deny; Azure Policy for AKS *is* OPA Gatekeeper; Kyverno mutate/generate = Modify/DINE. *(input)*
- [ ] **[2h] Lab — Kubernetes RBAC** — [labs/d1-kubernetes-rbac.md](../labs/d1-kubernetes-rbac.md) on the bare cluster: write a namespaced Role + RoleBinding, test with `kubectl auth can-i --as=…`, then audit over-permission with `kubectl who-can` and `rbac-tool analysis`. *(output)*
- [ ] **[2h] Lab — Governance & policy-as-code** — [labs/d1-governance-policy.md](../labs/d1-governance-policy.md): `cd lab-infra/governance && ./up.sh`, watch Kyverno and Gatekeeper **reject** a privileged/unlabelled pod at admission (then Audit/dryrun let it through), and score the cluster with `kubescape scan framework nsa`. `./down.sh` after. *(output)*
- [ ] **[1h] Prove the controls** — a denied `kubectl auth can-i`, a webhook admission rejection, a Kubescape compliance score you improve by remediating one control. Confirm the base cluster is clean.

## Day 6 — Flex and checkpoint

- [ ] **[1.5h] Weak-spot review** — revisit any objective whose quiz questions you missed (the tracker shows which); re-read that note section and re-run the relevant lab step. Slippage from earlier days lands here, never in Phase 2.
- [ ] **[1h] Walkthrough consolidation** — re-study the two walkthrough sections at full depth: SPIFFE/SPIRE attestation (`wi-spiffe`) and the Teleport access-request approval flow (`pam-approval`); confirm you can explain each without notes.
- [ ] **[1h] Catch-up / rest** — finish any leftover lab teardown; make sure `lab-infra/identity`, `pam`, and `governance` are all down and the cluster is clean before Phase 2.

## Checkpoint

- [ ] **[1h] Take Checkpoint 1** — [assessment/data/quiz-1.yaml](../assessment/data/quiz-1.yaml) (all 28 questions, pass ≥ 80%). Mark every Domain 1 objective in [tracker.yaml](../assessment/data/tracker.yaml) as done only when its note is read, its lab performed (or walkthrough studied), and its checkpoint questions passed.
- [ ] **If < 80%** — the missed objectives drive remediation on this flex day before Phase 2 starts. Re-run the specific lab step that proves the control; a control you can't demonstrate isn't learned.
