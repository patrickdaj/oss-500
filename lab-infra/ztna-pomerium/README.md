# lab-infra/ztna-pomerium — reference solution

The CI-validated Terraform **reference solution** for the Pomerium identity-aware-proxy lab ([`../../labs/d1-ztna-pomerium.md`](../../labs/d1-ztna-pomerium.md)). Build your own from the lab directions first; run this to check or compare.

## What it provisions (Terraform, `hashicorp/helm` provider)
A `helm_release` of the `pomerium/pomerium` chart into the local kind cluster, configured as an **identity-aware reverse proxy** (BeyondCorp): OIDC to **Keycloak** (the Domain 1 IdP) for authentication, and one **route** to an internal web app guarded by a **per-request identity policy** (email must match the allowed domain). No VPN, no standing network access — every request is re-authorized against identity + context.

## Prereqs
- Terraform ≥1.6; provider `hashicorp/helm`.
- The kind cluster up (`../kind/`) and the shared namespaces applied (`../shared/up.sh`) — Pomerium lands in the shared, PSA-labelled `oss500-ztna` namespace (`create_namespace = false`), so `part-of=oss500` finds it for teardown.
- Keycloak reachable as the OIDC IdP (Domain 1), and an `internal-app` Service in `default` to protect.
- A Pomerium OIDC client registered in Keycloak (id/secret → tfvars).

## Run
```bash
cp terraform.tfvars.example terraform.tfvars   # fill in IdP url/client/secret (gitignored)
./up.sh        # terraform init + apply (Helm release)
./down.sh      # terraform destroy
```
Deploy → browse the protected route → get bounced to Keycloak → allowed only if your identity matches policy → tear down. $0, local, no cloud account.

> Pomerium has no dedicated Terraform provider, so the deploy is a **Terraform-wrapped Helm release** (the D5 "TF where a provider exists, else as-code Helm" rule). The policy lives in the chart `values`, versioned with the rest of the lab.
