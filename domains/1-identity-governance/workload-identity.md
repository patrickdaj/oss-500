# Implement identity for workloads (managed-identity equivalent)

Domain 1, subsection 2 (`d1-workload-identity`). A *workload* identity is how a non-human process proves who it is without a shipped secret. On Azure that's a **managed identity** (and **workload identity federation** for out-of-cluster trust); on Kubernetes it's the **ServiceAccount** and its short-lived **projected token**, federated outward through the cluster's **OIDC issuer**, and — for mesh-grade service identity — **SPIFFE/SPIRE**. The whole point is the same as managed identities: no long-lived credential ever sits in the app. Primary lab: [d1-workload-identity](../../labs/d1-workload-identity.md); it runs on the base kind cluster (no extra `lab-infra` component, except the SPIRE walkthrough).

## Configure Kubernetes ServiceAccounts and bound projected tokens for workloads

*Objective: `wi-sa` · OSS: Kubernetes ServiceAccounts ≈ SC-500: Managed identities · Lab: [d1-workload-identity](../../labs/d1-workload-identity.md)*

Every pod runs as a **ServiceAccount** (the namespace `default` SA if you don't name one). The ServiceAccount *is* the workload's identity — the seed of both cluster RBAC and any external federation — which makes it the direct counterpart of an Azure **managed identity** attached to a compute resource. The critical modern detail is *how the token is delivered*. Since Kubernetes 1.22, pods get a **bound, projected service-account token** via the `TokenRequest` API: it is **audience-scoped**, **time-limited** (default ~1 h, kubelet-rotated), and **bound to the pod's lifecycle** — when the pod dies the token is invalid. This replaced the old forever-valid Secret-based token, and it is exactly the "short-lived, automatically rotated, no stored secret" property that makes a managed identity safer than a service-principal secret.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata: { name: reports, namespace: oss500-apps }
automountServiceAccountToken: false   # wi-sa: default-deny the token; opt in per pod
---
apiVersion: v1
kind: Pod
metadata: { name: reports, namespace: oss500-apps }
spec:
  serviceAccountName: reports          # wi-sa: this pod's identity
  containers:
    - name: app
      image: reports:latest
      volumeMounts: [{ name: token, mountPath: /var/run/secrets/tokens }]
  volumes:
    - name: token
      projected:
        sources:
          - serviceAccountToken:
              audience: vault           # wi-sa: audience-scoped to the intended relying party
              expirationSeconds: 3600   # short-lived, kubelet-rotated
              path: vault-token
```

Turning **`automountServiceAccountToken: false`** off by default (on the SA or per pod) is the baseline hardening step: a pod that doesn't call the API server has no business carrying an API token an attacker could steal. Audience-scoping matters just as much — a token minted `audience: vault` won't be accepted by the API server or any other relying party, containing blast radius the way a narrowly scoped managed-identity credential does.

Two mechanics worth knowing for the exam framing. First, you can mint a token out-of-band with `kubectl create token reports --audience vault --duration 3600s -n oss500-apps` — the same `TokenRequest` API the kubelet uses, handy for testing federation. Second, the *legacy* path still exists: creating a `Secret` of type `kubernetes.io/service-account-token` yields a non-expiring token, and pre-1.24 clusters auto-created one per SA. Finding such a Secret mounted or stored is the "long-lived credential" anti-pattern — the k8s equivalent of a service-principal client secret checked into a config.

Exam gotchas:

- **Modern SA tokens are bound + projected + audience-scoped + expiring** (`TokenRequest`); the legacy auto-generated Secret token was non-expiring and is the thing you want gone. "Long-lived token found mounted in a pod" is a finding, not a feature.
- **`automountServiceAccountToken: false`** is the default-deny for identity — set it on the `default` SA and opt in explicitly. The Azure parallel: don't attach an identity/credential a workload doesn't need.
- The **audience** claim is a scoping control: a token for `audience: vault` is rejected everywhere else. Mirrors an access token scoped to one resource.
- A ServiceAccount without any RoleBinding can still *authenticate* (it has an identity) but can't *do* anything in-cluster — identity and authorization are separate, exactly as in Azure (a managed identity with no role assignment).
- **A projected token is not a bearer secret to hoard**: it's short-lived and pod-bound, so exfiltrating it buys an attacker only minutes and only for the token's `audience`. Contrast with the legacy Secret token, which is a durable credential — the reason "migrate off Secret-based SA tokens" is a hardening recommendation.

**Resources:**
- [Kubernetes — Configure ServiceAccounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) (~20 min)
- [Kubernetes — Bound service account token volume projection](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#serviceaccount-token-volume-projection) (~15 min)
- [Kubernetes — ServiceAccounts (concept)](https://kubernetes.io/docs/concepts/security/service-accounts/) (~15 min)
- [Kubernetes — Managing ServiceAccounts (admin, token lifecycle)](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/) (~15 min)
- [Microsoft Learn — Managed identities for Azure resources (overview)](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview) (~15 min)

## Federate workload identity to secret/cloud systems via the cluster OIDC issuer

*Objective: `wi-oidc` · OSS: Kubernetes workload identity / OIDC ≈ SC-500: Workload identity federation · Lab: [d1-workload-identity](../../labs/d1-workload-identity.md)*

The reason a projected token is powerful *outside* the cluster is that the API server is an **OIDC issuer**: it publishes a discovery document and a JWKS of public signing keys, so any system that trusts that issuer can validate a service-account token *cryptographically, offline*, with no shared secret. This is precisely **Azure workload identity federation**: instead of giving a workload a client secret, you configure a **federated credential** that trusts an external issuer + subject, and the workload trades its own OIDC token for a cloud access token. Same trust triangle, open-source parts.

```bash
# The cluster's OIDC discovery + signing keys — what an external relying party trusts
kubectl get --raw /.well-known/openid-configuration
kubectl get --raw /openid/v1/jwks
```

Two federation styles you should be able to tell apart:

- **TokenReview-based (Vault Kubernetes auth):** the relying party (e.g. HashiCorp Vault's `kubernetes` auth method) calls the cluster's `TokenReview` API to validate a presented SA token online. Trust is "ask the cluster if this token is real." Simple, but the validator needs network reach and a reviewer credential.
- **JWKS/OIDC-based (Vault JWT auth, cloud federation):** the relying party is configured with the cluster's **issuer URL** and validates the token's signature against the **JWKS** offline, checking `iss`, `sub` (the `system:serviceaccount:<ns>:<name>` subject), `aud`, and expiry. This is how cloud providers (AWS IRSA, GCP, **Azure workload identity federation**) trust a Kubernetes workload — configure the issuer once, then bind a specific `subject`/`audience` to a role.

The security invariant in both: bind on the **exact subject and audience**, not a wildcard. A Vault role or cloud federated credential that trusts *any* service account in the issuer is the over-broad-trust failure — the equivalent of a federated credential whose subject filter matches too much.

Exam gotchas:

- **No stored secret** is the whole win: the workload presents a token *it already has*; the relying party validates it via TokenReview or JWKS. This is the managed-identity/workload-federation value proposition — match it to "eliminate the client secret."
- **Bind on `sub` (`system:serviceaccount:ns:name`) + `aud`** exactly. Trusting the issuer alone, or a wildcard subject, lets any pod assume the role — a real escalation and a favorite distractor.
- **TokenReview (online) vs JWKS/OIDC (offline)** are two valid designs; cloud federation and Vault JWT auth use JWKS, Vault's `kubernetes` auth uses TokenReview. Know which needs cluster network reach.
- The cluster must **publish a stable, reachable issuer** (`--service-account-issuer`); a private/unreachable or rotated issuer URL breaks external validation — the analogue of a broken federation metadata endpoint.
- For cloud federation the relying party needs the JWKS **reachable at token-exchange time** (or the keys cached) and the SA token minted with the cloud's expected **audience** (e.g. `api://AzureADTokenExchange` for Azure). A default-audience k8s token won't be accepted — a common "federation configured but exchange fails" bug.

**Resources:**
- [Kubernetes — ServiceAccount issuer discovery (OIDC)](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#service-account-issuer-discovery) (~15 min)
- [HashiCorp Vault — Kubernetes and JWT/OIDC auth methods](https://developer.hashicorp.com/vault/docs/auth/kubernetes) (~20 min)
- [Microsoft Learn — Workload identity federation (the SC-500 control)](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation) (~20 min)
- [Azure AD Workload Identity — federating k8s ServiceAccounts to Entra](https://azure.github.io/azure-workload-identity/docs/) (~20 min)
- [AWS — IAM roles for service accounts (IRSA), the same OIDC pattern](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) (~20 min)

## Explain SPIFFE/SPIRE workload identity and mTLS-based service identity

*Objective: `wi-spiffe` · OSS: SPIFFE/SPIRE ≈ SC-500: Managed identities for services · Lab: [d1-workload-identity](../../labs/d1-workload-identity.md) (walkthrough)*

Kubernetes ServiceAccount tokens identify a workload *to the API server and to systems that trust its issuer*. **SPIFFE** (Secure Production Identity Framework For Everyone) generalizes this to a platform-agnostic **service identity** usable for **service-to-service mTLS** anywhere — across clusters, VMs, and clouds — which is why it's the closest open-source analogue to "managed identities for services" plus the identity layer a service mesh needs. A workload's identity is a **SPIFFE ID**, a URI like `spiffe://oss500.local/ns/oss500-apps/sa/reports`, carried in a short-lived **SVID** (an X.509 certificate or a JWT).

**SPIRE** is the reference implementation — the runtime that issues and rotates SVIDs:

- The **SPIRE server** is the trust-domain CA and registration authority. It holds **registration entries** mapping *selectors* (attested facts about a workload) to a SPIFFE ID.
- The **SPIRE agent** runs on each node. It performs **node attestation** (proving the node's identity, e.g. via a k8s PSAT / cloud instance document) and then **workload attestation** — inspecting the calling process's kernel/k8s facts (namespace, ServiceAccount, labels) through the local **Workload API** (a Unix socket) — and hands the workload an SVID only if the selectors match. The workload never holds a long-lived key; SVIDs are minted just-in-time and rotated automatically.

The payoff is **mutual TLS with cryptographic identity on both ends**: two services present X.509-SVIDs, each validates the other's SPIFFE ID against the trust bundle, and you author authorization as "`spiffe://.../sa/frontend` may call `spiffe://.../sa/payments`." This is the identity substrate under meshes like Istio and is the zero-trust, no-shared-secret service identity that Azure managed identities give a single service — generalized to every hop.

Exam gotchas:

- **SPIFFE = the identity spec (SPIFFE ID + SVID); SPIRE = the implementation** (server CA + node/workload attestation). Don't conflate the standard with the runtime.
- **Node attestation then workload attestation**: the agent proves the node, then proves the specific workload via selectors before issuing an SVID — attestation, not a shared secret, is the trust root.
- SVIDs are **short-lived and auto-rotated**; the workload fetches them from the local **Workload API** socket and never stores a key — the same "no long-lived credential" property as a managed identity, extended to mTLS.
- SPIFFE's job is **service-to-service identity/mTLS**, distinct from a Kubernetes SA token used to authenticate *to the API server or an external OIDC relying party*; a mesh mTLS question points at SPIFFE, an "authenticate to Vault/cloud" question points at `wi-oidc`.
- **X509-SVID vs JWT-SVID**: X.509-SVIDs power mTLS (identity on both ends of the connection); JWT-SVIDs are bearer tokens for cases where you can't do mTLS (e.g. through an L7 proxy). Mixing them up matters — a bearer JWT-SVID replayed is a theft risk that mTLS's proof-of-possession avoids.
- The **trust bundle** (the trust-domain CA's public keys) is what each side validates the peer's SVID against; cross-trust-domain communication needs **federation** of bundles, the mesh analogue of exchanging federation metadata between tenants.

**Resources:**
- [SPIFFE overview](https://spiffe.io/docs/latest/spiffe-about/overview/) (~15 min)
- [SPIRE concepts — server, agent, attestation](https://spiffe.io/docs/latest/spire-about/spire-concepts/) (~20 min)
- [SPIFFE-ID specification (URI format, trust domain)](https://github.com/spiffe/spiffe/blob/main/standards/SPIFFE-ID.md) (~15 min)
- [SPIRE — Quickstart for Kubernetes (hands-on)](https://spiffe.io/docs/latest/try/getting-started-k8s/) (~30 min)
- [Istio — Security concepts (SPIFFE identities, mTLS)](https://istio.io/latest/docs/concepts/security/) (~20 min)

## Summary

| Objective | Takeaway |
|---|---|
| `wi-sa` | ServiceAccount = the workload's identity (managed-identity analogue); modern tokens are bound/projected/audience-scoped/expiring; set `automountServiceAccountToken: false` by default |
| `wi-oidc` | Cluster is an OIDC issuer (discovery + JWKS); relying parties federate via TokenReview (online) or JWKS/OIDC (offline); bind on exact `sub`+`aud`, never a wildcard — no stored secret |
| `wi-spiffe` | SPIFFE ID + SVID = platform-agnostic service identity for mTLS; SPIRE issues/rotates SVIDs after node + workload attestation; identity substrate for a service mesh |
