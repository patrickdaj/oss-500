# lab-infra/ztna-openziti — reference solution

The CI-validated Terraform **reference solution** for the OpenZiti overlay lab ([`../../labs/d1-ztna-openziti.md`](../../labs/d1-ztna-openziti.md)). Build your own from the lab directions first; run this to check or compare.

## What it provisions (Terraform, `netfoundry/ziti` provider)
Two `ziti_identity`s (a **client** that dials, a **host** that binds), split by role attribute (`#client` / `#host-app`) · a `ziti_intercept_v1_config` (the overlay-only address the client dials) + a `ziti_host_v1_config` (where the hosting tunneler forwards) bundled into one `ziti_service` (`#private-app`) · a **Dial** and a **Bind** `ziti_service_policy` so only the client may dial and only the host may bind · service/edge-router policies for reachability. The app is reached **by name over the mesh** — the underlay has **zero listening ports** for it, so there's nothing to scan.

## Prereqs
- Terraform ≥1.6; provider `netfoundry/ziti`.
- A local controller + edge router: `ziti edge quickstart` (all-in-one). Admin creds from tfvars.
- Two `ziti-edge-tunnel` instances (client + host) enrolled with the tokens `up.sh` prints.

## Run
```bash
cp terraform.tfvars.example terraform.tfvars   # fill in mgmt host/creds/backend (gitignored)
./up.sh        # terraform init + apply, prints the enrollment tokens
./down.sh      # terraform destroy
```
Deploy → enroll the tunnelers → dial the private app by its overlay name with no underlay exposure → tear down. $0, local, no cloud account.
