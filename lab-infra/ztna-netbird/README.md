# lab-infra/ztna-netbird — reference solution

The CI-validated Terraform **reference solution** for the NetBird WireGuard-mesh lab ([`../../labs/d1-ztna-netbird.md`](../../labs/d1-ztna-netbird.md)). Build your own from the lab directions first; run this to check or compare.

## What it provisions (Terraform, `netbirdio/netbird` provider)
Two `netbird_group`s (`admins`, `servers`) · two reusable `netbird_setup_key`s that enroll a device **straight into its group** (identity at join time) · one `netbird_policy` allowing `admins → servers` on SSH, **one-directional**, and nothing else. Devices form an encrypted WireGuard mesh via a **self-hosted control plane**; access is governed by **group ACLs, not network position** — joining the mesh grants no lateral reach on its own (default deny).

## Prereqs
- Terraform ≥1.6; provider `netbirdio/netbird`.
- A self-hosted NetBird control plane ($0, local) — the official `getting-started-with-zitadel` docker-compose quickstart — reachable at `management_url`.
- A PAT / service-user token (→ tfvars) and the `netbird` client on the peers.

## Run
```bash
cp terraform.tfvars.example terraform.tfvars   # fill in management_url + token (gitignored)
./up.sh        # terraform init + apply, prints the setup keys
./down.sh      # terraform destroy
```
Deploy → enroll an "admin" and a "server" peer with their keys → confirm admin can SSH the server but not vice-versa, and no other ports open → tear down. $0, local, self-hosted control plane, no cloud account.

> **Why NetBird (not Headscale/Tailscale):** NetBird is fully OSS *including* the control plane **and** ships an official Terraform provider for groups/keys/policies — so the mesh is genuinely as-code. Headscale has no TF provider; Tailscale's provider targets its SaaS (breaks the no-account thesis).
