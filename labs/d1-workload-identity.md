# Lab d1: Workload Identity

Prove a workload has an identity with **no stored secret** — a bound, audience-scoped, expiring token a relying party validates cryptographically — and see why binding on the exact subject and audience is what keeps it safe.

**Objectives covered**

| id | Objective |
|---|---|
| `wi-sa` | Configure Kubernetes ServiceAccounts and bound projected tokens for workloads |
| `wi-oidc` | Federate workload identity to secret/cloud systems via the cluster OIDC issuer |
| `wi-spiffe` | Explain SPIFFE/SPIRE workload identity and mTLS-based service identity *(walkthrough section)* |

**SC-500 correspondence**: Managed identities (`wi-sa`), Workload identity federation (`wi-oidc`), Managed identities for services / mesh identity (`wi-spiffe`).

**Prerequisites**
- The shared **Phase 0 kind cluster** is up (reused by every lab) — check with `kind get clusters` (you should see `oss500`). If it isn't, create it once: `kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml` then `lab-infra/shared/up.sh` (namespaces incl. `oss500-apps`). *No `identity`/`pam` component needed.*
- Notes read: [workload-identity.md](../domains/1-identity-governance/workload-identity.md)
- `jq` and a base64 decoder on the host to inspect tokens

**Estimated time**: 2–3 h · $0 (local)

## Challenge

Build a workload identity that carries **no stored secret**: a pod whose credential is short-lived, bound to its exact ServiceAccount, and scoped to a specific audience — then get a relying party to validate that credential two different ways (online and offline). No solution below — that's what you're building.

Reach these observables:
- A ServiceAccount configured so pods get **no** implicit API token by default, plus a pod that explicitly requests a bound, audience-scoped, expiring projected token. Decoded, it shows a short `exp`, `aud: ["vault"]`, and `sub: system:serviceaccount:oss500-apps:reports`; the pod has **no** token at the default (legacy) SA path.
- A `TokenReview` of your minted token returns `authenticated: true` for the `vault` audience, but the **same token reviewed for a different audience is rejected** — proving the trust binding pins on exact `sub` + `aud`, not just the issuer.
- (Walkthrough, no command to run) Be able to trace how a SPIFFE/SPIRE SVID is issued only after node + workload attestation, and how two SPIFFE IDs mutually authenticate over mTLS.

## Build it (guided)

### Part A — ServiceAccounts & bound projected tokens (`wi-sa`)

1. **Build a ServiceAccount that opts out of the default token, and a pod that opts back in explicitly.** In `oss500-apps`, define a `ServiceAccount` named `reports` with `automountServiceAccountToken: false` — this is the default-deny: no pod gets an implicit API token unless it explicitly asks. Then write a `Pod` that uses this ServiceAccount, running a container that satisfies the namespace's `restricted` Pod Security Standard (non-root, no privilege escalation, `RuntimeDefault` seccomp, all capabilities dropped), with a `projected` volume whose source is a `serviceAccountToken`. Your turn: choose the `audience` (name the relying party this token is scoped to — this lab treats it as `vault`), a short `expirationSeconds` (kubelet rotates it before it goes stale), and a mount path for the token file. Apply it.

2. **Decode the token and read its claims.** A projected service account token is a JWT — exec into the pod, `cat` the token file, and decode it (hint: split on `.`, base64-decode the middle segment, pipe through `jq`). Confirm three things: the `sub` names exactly this ServiceAccount, the `aud` is scoped to the audience you chose, and the `exp` is roughly an hour out. This is the managed-identity property in miniature: identity backed by a short-lived, scoped, unstored credential — nothing was ever written to a Secret.

3. **Prove default-deny actually holds.** Your turn: check whether the legacy, unscoped API-token path (`/var/run/secrets/kubernetes.io/serviceaccount/`) exists inside the pod. It shouldn't — `automountServiceAccountToken: false` kept it out entirely. A pod that never got that mount carries nothing an attacker could steal off the filesystem.

### Part B — Federate via the cluster OIDC issuer (`wi-oidc`)

4. **See what an external relying party would trust.** The Kubernetes API server is itself an OIDC issuer. Query its discovery document and its JWKS (public signing keys) — these are the two unauthenticated endpoints a cloud provider or Vault would be configured against for **offline** signature validation.

5. **Mint an audience-scoped token on demand.** Use the `TokenRequest` API (via `kubectl create token`) to mint a fresh token for the `reports` ServiceAccount, explicitly scoped to the `vault` audience, with a duration of your choosing. Decode it as in step 2 and confirm the `aud` claim matches.

6. **Build a `TokenReview` — the online-validation path.** This is how something like Vault's `kubernetes` auth method checks a presented token without ever holding the signing key itself: it asks the cluster. Construct a `TokenReview` (`authentication.k8s.io/v1`) whose `spec.token` is the token you just minted and whose `spec.audiences` is `["vault"]`; submit it and read `status`. You should see `authenticated: true` and the SA identity. Your turn: repeat the exact same review but with `spec.audiences: ["wrong"]` — what does `status` say now? Audience scoping has to be a real boundary, not a decoration.

7. **Reason through the offline path (JWKS/OIDC).** A relying party using offline validation — cloud workload identity federation, or Vault's JWT auth method — is configured with the issuer URL, validates a token's signature against the JWKS, then checks `iss`, `sub`, `aud`, `exp` itself. The design question that matters on the exam: which field in that binding has to pin the **exact** `sub`, and why would binding on the issuer alone (or a wildcard subject) let *any* pod in the cluster assume the role? Sketch the binding — you don't need Vault running to reason about which field unlocks the role, which scopes it to one audience, and which pins it to exactly this ServiceAccount.

### Part C — SPIFFE/SPIRE service identity (`wi-spiffe`) — WALKTHROUGH

*mTLS-based service identity is impractical to stand up fully alongside the rest of the lab; documented here at exam depth and marked `walkthrough` in the tracker.*

8. **Trace the identity model.** A workload's SPIFFE identity is a URI like `spiffe://oss500.local/ns/oss500-apps/sa/reports`, carried in a short-lived **SVID** (X.509 certificate or JWT) — platform-agnostic, usable for mTLS across clusters, VMs, and clouds. Compare this to the projected token you built in Part A: what plays the same role here?

9. **Trace the trust architecture.** The **SPIRE server** is the trust-domain CA plus registration authority: it holds **registration entries** mapping *selectors* (attested facts about a workload) to a SPIFFE ID. The **SPIRE agent** runs per node. Where would the registration entry for `reports` need to point?

10. **Trace attestation.** Two-stage attestation is the trust root, replacing any shared secret entirely: the agent first does **node attestation** (proving the node itself — e.g. k8s PSAT, or cloud instance identity), then **workload attestation** — inspecting the caller's namespace/ServiceAccount/labels via the local **Workload API** Unix socket — and only issues an SVID if the selectors match.

11. **Trace mTLS.** Two services each present an X.509-SVID and validate the peer's SPIFFE ID against the trust bundle, so authorization is written as "`spiffe://.../sa/frontend` may call `spiffe://.../sa/payments`." SVIDs auto-rotate and are fetched from the Workload API — the mesh identity substrate (Istio uses exactly this), the no-shared-secret idea from Part A extended to every hop.

## Verification

- **`wi-sa`:** the decoded projected token shows a short `exp`, `aud: ["vault"]`, and `sub: system:serviceaccount:oss500-apps:reports`; the pod with `automountServiceAccountToken: false` has **no** token at the default SA path (observable via a failed `ls`).
- **`wi-oidc`:** a `TokenReview` of a `vault`-audience token returns `authenticated: true` with the SA identity, while the **same token reviewed for a different audience is rejected** — federation binds on exact `sub`+`aud`.
- **`wi-spiffe`:** you can trace how an SVID is issued only after node + workload attestation and how two SPIFFE IDs mutually authenticate over mTLS.

## Reference solution
Build it yourself first; check after.

### Part A — ServiceAccounts & bound projected tokens

1. ServiceAccount + pod with a bound, audience-scoped projected token:
   ```yaml
   apiVersion: v1
   kind: ServiceAccount
   metadata: { name: reports, namespace: oss500-apps }
   automountServiceAccountToken: false        # wi-sa: default-deny the token; opt in per pod
   ---
   apiVersion: v1
   kind: Pod
   metadata: { name: reports, namespace: oss500-apps }
   spec:
     serviceAccountName: reports              # wi-sa: this pod's identity
     containers:
       - name: app
         image: cgr.dev/chainguard/wolfi-base
         command: ["sleep", "3600"]
         securityContext:                     # restricted PSS (oss500-apps enforces restricted)
           runAsNonRoot: true
           allowPrivilegeEscalation: false
           seccompProfile: { type: RuntimeDefault }
           capabilities: { drop: ["ALL"] }
         volumeMounts: [{ name: token, mountPath: /var/run/secrets/tokens, readOnly: true }]
     volumes:
       - name: token
         projected:
           sources:
             - serviceAccountToken:
                 audience: vault               # wi-sa: audience-scoped to the intended relying party
                 expirationSeconds: 3600       # short-lived, kubelet-rotated
                 path: vault-token
   ```
   `kubectl apply -f reports.yaml`.

2. Decode the projected token and read its claims:
   ```bash
   kubectl -n oss500-apps exec reports -- cat /var/run/secrets/tokens/vault-token \
     | cut -d. -f2 | base64 -d 2>/dev/null | jq '{iss,sub,aud,exp}'
   ```
   Confirm `sub: system:serviceaccount:oss500-apps:reports`, `aud: ["vault"]`, and an `exp` ~1 h out. This is the managed-identity property: identity with a short-lived, scoped, unstored credential.

3. Prove default-deny works: exec into a pod using the **default** SA (or check this pod's legacy path) — `kubectl -n oss500-apps exec reports -- ls /var/run/secrets/kubernetes.io/serviceaccount/` returns **no such file/directory**, because `automountServiceAccountToken: false` kept the API token out. A pod that doesn't call the API server carries no token to steal.

### Part B — Federate via the cluster OIDC issuer

4. The API server is an OIDC issuer — view what an external relying party would trust:
   ```bash
   kubectl get --raw /.well-known/openid-configuration | jq .
   kubectl get --raw /openid/v1/jwks | jq .          # public signing keys — offline validation
   ```
5. Mint a token for a specific audience with the `TokenRequest` API: `kubectl -n oss500-apps create token reports --audience=vault --duration=1h`. Decode it (as in step 2) and confirm `aud: ["vault"]`.
6. **TokenReview (online validation)** — how Vault's `kubernetes` auth method validates a presented token by asking the cluster:
   ```bash
   TOKEN=$(kubectl -n oss500-apps create token reports --audience=vault)
   kubectl create -o json -f - <<EOF | jq '.status'
   apiVersion: authentication.k8s.io/v1
   kind: TokenReview
   spec: { token: "$TOKEN", audiences: ["vault"] }
   EOF
   ```
   `status.authenticated: true` and the user `system:serviceaccount:oss500-apps:reports`. Now repeat with `audiences: ["wrong"]` → the review reports the token isn't valid for that audience. Audience scoping is a real boundary.
7. **JWKS/OIDC (offline validation)** — the cloud-federation style: a relying party (Vault JWT auth, or Azure/AWS/GCP workload identity federation) is configured with the issuer URL and validates the token's signature against the JWKS, checking `iss`, `sub`, `aud`, `exp`. The trust binding must pin the **exact** `sub` and `aud`:
   ```bash
   # Conceptual Vault binding — trust ONLY this SA for this audience, never a wildcard
   vault write auth/jwt/role/reports \
     role_type=jwt bound_audiences=vault user_claim=sub \
     bound_subject=system:serviceaccount:oss500-apps:reports policies=reports-read ttl=1h
   ```
   A role that trusts the issuer alone (or `bound_subject=*`) would let *any* pod assume it — the over-broad-trust failure.

If your projected token omits `audience`, or your `TokenReview`/Vault role checks only `iss` and not `sub`, the binding degrades to "any pod in this cluster" — key every trust decision on the exact `sub` **and** `aud` pair.

## Teardown

- `kubectl delete pod reports sa/reports -n oss500-apps` (and any second demo pod). The base cluster stays up for later labs.

## What the exam asks

- **Modern SA tokens are bound + projected + audience-scoped + expiring** (`TokenRequest`); a long-lived Secret-based token mounted in a pod is a *finding*, not a feature. `automountServiceAccountToken: false` is the default-deny.
- **No stored secret** is the win: the workload presents a token it already has; the relying party validates it via **TokenReview (online)** or **JWKS/OIDC (offline)**. Cloud/Vault-JWT federation uses JWKS; Vault `kubernetes` auth uses TokenReview.
- **Bind on the exact `sub` + `aud`**, never a wildcard — trusting the issuer alone lets any pod assume the role (a real escalation and a favorite distractor).
- **SPIFFE = the spec (ID + SVID); SPIRE = the implementation** (server CA + node/workload attestation). Mesh mTLS → SPIFFE; "authenticate to Vault/cloud" → the OIDC/TokenReview path.
