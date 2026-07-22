# Lab d1: Identity-Aware Reverse Proxy with Pomerium *(beyond-blueprint)*

Put an internal web app behind a proxy that re-authorizes **every request** against identity and context — BeyondCorp, no VPN, no standing network access. The identity-aware-proxy ZTNA model (D1 `ztna-pomerium`), deployed as a Terraform-wrapped Helm release, using the **Keycloak** IdP from Domain 1.

**Objectives covered**

| id | Objective |
|---|---|
| `ztna-pomerium` | Front an internal app with an identity-aware reverse proxy (BeyondCorp) |

**SC-500 correspondence**: Microsoft Entra **Private Access / Application Proxy** — publish an internal app to authenticated users without exposing the network. **Standards**: NIST SP 800-207 (the proxy is the PEP; the IdP is the PDP input); per-request authorization is the ZTMM "never trust, continually verify" pillar. Bypassing it maps to ATT&CK **T1133 (External Remote Services)** — the control removes the standing remote-access surface.

**Prerequisites**
- Terraform ≥1.6; the kind cluster up (`../lab-infra/kind/`); Keycloak reachable as the OIDC IdP (Domain 1 lab); an `internal-app` Service in `default` (any small HTTP app).
- A Pomerium OIDC client registered in Keycloak (client id + secret).
- Notes read: [`../domains/1-identity-governance/ztna-access-models.md`](../domains/1-identity-governance/ztna-access-models.md).

**Estimated time**: 2 h · $0 (local)

> **Directions-first.** Build the Terraform/Helm values yourself from the steps below. A CI-validated **reference solution** lives in [`../lab-infra/ztna-pomerium/`](../lab-infra/ztna-pomerium/); use it to check your work, not to copy.

## Challenge

Front the `internal-app` Service with Pomerium so that identity is checked on **every single request**, not once at a VPN handshake. Build it yourself (Part A + Part B below), then reach these three observables — no solution here, they're what you're driving toward:

- **Unauthenticated** hit on the protected route → a **302 redirect to Keycloak** to log in. The proxy admits no one anonymously.
- **Authenticated but out-of-policy** user (valid Keycloak credentials, wrong email domain) → **403** from Pomerium. Valid identity is not the same as authorized identity.
- **No path to `internal-app` except through Pomerium** — the app has no ingress of its own; the proxy is the only door.

A CI-validated reference lives in [`../lab-infra/ztna-pomerium/`](../lab-infra/ztna-pomerium/) — build first, check after.

## Build it (guided)

### Part A — register Pomerium at the IdP

Pomerium is itself an OIDC *client* of Keycloak — it needs to prove its own identity to the IdP before it can broker anyone else's. In Keycloak (Domain 1 realm), create a **confidential** OIDC client named `pomerium`.

**Your turn:**
- What redirect URI does Pomerium's `authenticate` service need registered? (Hint: it's the callback path Pomerium's authenticate service exposes for the OIDC code exchange — check the chart docs for the `authenticate` service's external URL/route and give it a `/oauth2/callback`-style path.)
- Generate the client secret and hold onto both the client id and secret — they go into your `terraform.tfvars`, never into committed files.

### Part B — deploy the proxy (`ztna-pomerium`)

Why Terraform-wrapped Helm, not a native provider: Pomerium has no dedicated Terraform provider, so this lab follows the "Terraform where a provider exists, else as-code Helm" rule — you still get a `terraform apply`/`destroy` lifecycle, but the actual Pomerium configuration lives in Helm chart `values`.

Author a `.tf` file using the `hashicorp/helm` provider that releases the `pomerium/pomerium` chart into your cluster. Work out the `values` yourself — three things have to be true when you're done:

1. **Authentication is wired to Keycloak.** Pomerium's `authenticate.idp` block needs `provider = "oidc"` plus a `url`, `clientID`, and `clientSecret` pointing at your Domain 1 Keycloak and the client you just created in Part A. (Hint: don't hardcode the secret in the `.tf` file — pull it from a Terraform variable backed by `terraform.tfvars`, gitignored.)
2. **Exactly one route exists**, from your public hostname (e.g. `https://app.localtest.me`) to the internal Service's cluster-DNS name (`http://internal-app.default.svc.cluster.local`). This is the *only* path in — think about what it means that nothing else in the cluster exposes this Service externally.
3. **A policy gates that route.** This is the per-request identity check the whole lab is about: `allow` only when the authenticated user's email `domain` matches an allowed domain you choose. Everyone else gets a valid login but a denied route.

Sketch the `values` shape before you write HCL — what nests under `authenticate`, what nests under `config.routes`, and where the `policy` block attaches to a route. Then:

```bash
terraform fmt
terraform init
terraform apply
```

Watch the plan before you approve it — does it only touch the `helm_release` you intended?

## Verification
```bash
# In a browser (or with cookies), hit the protected route:
open https://app.localtest.me
```
- Unauthenticated → you're **redirected to Keycloak** to log in (the proxy admits no one anonymously).
- Log in as a user **in** the allowed domain → you reach `internal-app`.
- Log in as a user **outside** the policy → Pomerium returns **403**, even with valid credentials — authentication ≠ authorization.
- There is **no route to `internal-app` except through Pomerium** — the app has no ingress of its own.

## Reference solution

**Build it yourself first; check after.** The full, CI-validated Terraform + Helm-values solution lives in [`../lab-infra/ztna-pomerium/`](../lab-infra/ztna-pomerium/) — build your own from Parts A and B above, then use these to check or compare, not to copy:

- [`main.tf`](../lab-infra/ztna-pomerium/main.tf) — the complete `helm_release` resource: `authenticate.idp` (`provider = "oidc"`, `url`/`clientID`/`clientSecret` from variables), the single `config.routes` entry (`from = https://app.localtest.me` → `to = http://internal-app.default.svc.cluster.local`), and the route `policy` (`allow.and` on `domain.is == var.allowed_domain`).
- [`variables.tf`](../lab-infra/ztna-pomerium/variables.tf) — `kubeconfig_path`, `kube_context`, `namespace`, the OIDC `idp_provider_url`/`idp_client_id`/`idp_client_secret` (sensitive), and `allowed_domain`.
- [`terraform.tfvars.example`](../lab-infra/ztna-pomerium/terraform.tfvars.example) — copy to `terraform.tfvars` (gitignored) and fill in the Keycloak client id/secret from Part A plus your `allowed_domain`.
- [`up.sh`](../lab-infra/ztna-pomerium/up.sh) — checks `terraform.tfvars` exists, then runs `terraform init -input=false` and `terraform apply -input=false -auto-approve` (equivalent to the `terraform fmt`/`init`/`apply` sequence in Part B).
- [`down.sh`](../lab-infra/ztna-pomerium/down.sh) — `terraform destroy -input=false -auto-approve`.
- [`README.md`](../lab-infra/ztna-pomerium/README.md) — prereqs and the deploy → browse → bounced-to-Keycloak → allowed-if-policy-matches → teardown flow, plus the note on why this is a Terraform-wrapped Helm release rather than a native provider.

If your policy allowed the route with no `domain` condition, you've built an authenticate-only proxy, not an authorize-on-every-request one — go back and make the `policy` block do real work. If you find yourself hardcoding the client secret directly into `main.tf`, move it to a `sensitive` variable backed by `terraform.tfvars` instead.

## Teardown
```bash
terraform destroy     # or ../lab-infra/ztna-pomerium/down.sh
```

## What the exam asks
SC-500 frames this as **Entra Private Access / App Proxy**: publish an internal app to the right users without a VPN or public exposure. The transferable concept is BeyondCorp — the *proxy* is the enforcement point and it re-checks identity + context on **every request**, so there's no "inside the network = trusted." Whether the tool is Pomerium or Entra, the app is never directly reachable and every hit is authorized fresh.
