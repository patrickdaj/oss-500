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

## Steps — build it yourself

### Part A — register Pomerium at the IdP
In Keycloak (Domain 1), create a confidential OIDC client `pomerium` with a redirect URI for the authenticate service. Note the client id + secret → `terraform.tfvars`.

### Part B — deploy the proxy (`ztna-pomerium`)
Author Terraform (`hashicorp/helm` provider) that releases the `pomerium/pomerium` chart into the cluster with `values` that set:
1. `authenticate.idp` → `provider = "oidc"`, `url`/`clientID`/`clientSecret` pointing at Keycloak.
2. One `config.routes` entry: `from = https://app.localtest.me` → `to = http://internal-app.default.svc.cluster.local`.
3. A **policy** on that route: `allow` only when the user's email `domain` matches your allowed domain — the per-request identity gate.

`terraform fmt`, `init`, `apply`.

## Verification
```bash
# In a browser (or with cookies), hit the protected route:
open https://app.localtest.me
```
- Unauthenticated → you're **redirected to Keycloak** to log in (the proxy admits no one anonymously).
- Log in as a user **in** the allowed domain → you reach `internal-app`.
- Log in as a user **outside** the policy → Pomerium returns **403**, even with valid credentials — authentication ≠ authorization.
- There is **no route to `internal-app` except through Pomerium** — the app has no ingress of its own.

## Teardown
```bash
terraform destroy     # or ../lab-infra/ztna-pomerium/down.sh
```

## What the exam asks
SC-500 frames this as **Entra Private Access / App Proxy**: publish an internal app to the right users without a VPN or public exposure. The transferable concept is BeyondCorp — the *proxy* is the enforcement point and it re-checks identity + context on **every request**, so there's no "inside the network = trusted." Whether the tool is Pomerium or Entra, the app is never directly reachable and every hit is authorized fresh.
