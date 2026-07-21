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
- Base kind cluster up: `kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml` then `lab-infra/shared/up.sh` (namespaces incl. `oss500-apps`). *No `identity`/`pam` component needed.*
- Notes read: [workload-identity.md](../domains/1-identity-governance/workload-identity.md)
- `jq` and a base64 decoder on the host to inspect tokens

**Estimated time**: 2–3 h · $0 (local)

## Steps

### Part A — ServiceAccounts & bound projected tokens (`wi-sa`)

1. Create a ServiceAccount that does **not** auto-mount its token, and a pod that uses it with an explicit projected token:

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

### Part B — Federate via the cluster OIDC issuer (`wi-oidc`)

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

### Part C — SPIFFE/SPIRE service identity (`wi-spiffe`) — WALKTHROUGH

*mTLS-based service identity is impractical to stand up fully alongside the rest of the lab; documented here at exam depth and marked `walkthrough` in the tracker.*

8. **SPIFFE ID + SVID:** a workload's identity is a URI like `spiffe://oss500.local/ns/oss500-apps/sa/reports`, carried in a short-lived **SVID** (X.509 certificate or JWT). Platform-agnostic — usable for mTLS across clusters, VMs, and clouds.
9. **SPIRE server** = the trust-domain CA + registration authority; it holds **registration entries** mapping *selectors* (attested facts) to a SPIFFE ID. **SPIRE agent** runs per node.
10. **Two-stage attestation:** the agent first does **node attestation** (proves the node, e.g. k8s PSAT / cloud instance identity), then **workload attestation** — inspecting the caller's namespace/ServiceAccount/labels via the local **Workload API** Unix socket — and issues an SVID only if the selectors match. No shared secret anywhere; attestation is the trust root.
11. **mTLS:** two services each present an X.509-SVID and validate the peer's SPIFFE ID against the trust bundle, so you author authz as "`spiffe://.../sa/frontend` may call `spiffe://.../sa/payments`." SVIDs are auto-rotated and fetched from the Workload API — the mesh identity substrate (Istio uses this), the no-shared-secret managed-identity idea extended to every hop.

## Verification

- **`wi-sa`:** the decoded projected token shows a short `exp`, `aud: ["vault"]`, and `sub: system:serviceaccount:oss500-apps:reports`; the pod with `automountServiceAccountToken: false` has **no** token at the default SA path (observable via a failed `ls`).
- **`wi-oidc`:** a `TokenReview` of a `vault`-audience token returns `authenticated: true` with the SA identity, while the **same token reviewed for a different audience is rejected** — federation binds on exact `sub`+`aud`.
- **`wi-spiffe`:** you can trace how an SVID is issued only after node + workload attestation and how two SPIFFE IDs mutually authenticate over mTLS.

## Teardown

- `kubectl delete pod reports sa/reports -n oss500-apps` (and any second demo pod). The base cluster stays up for later labs.

## What the exam asks

- **Modern SA tokens are bound + projected + audience-scoped + expiring** (`TokenRequest`); a long-lived Secret-based token mounted in a pod is a *finding*, not a feature. `automountServiceAccountToken: false` is the default-deny.
- **No stored secret** is the win: the workload presents a token it already has; the relying party validates it via **TokenReview (online)** or **JWKS/OIDC (offline)**. Cloud/Vault-JWT federation uses JWKS; Vault `kubernetes` auth uses TokenReview.
- **Bind on the exact `sub` + `aud`**, never a wildcard — trusting the issuer alone lets any pod assume the role (a real escalation and a favorite distractor).
- **SPIFFE = the spec (ID + SVID); SPIRE = the implementation** (server CA + node/workload attestation). Mesh mTLS → SPIFFE; "authenticate to Vault/cloud" → the OIDC/TokenReview path.
