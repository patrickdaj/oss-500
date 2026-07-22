# Lab d1: WireGuard Mesh with Identity ACLs using NetBird *(beyond-blueprint)*

Build a device-level encrypted **WireGuard mesh** with a **self-hosted control plane**, where access between peers is governed by **identity group ACLs, not network position** — joining the mesh grants no lateral reach on its own. The mesh ZTNA model (D1 `ztna-netbird`), as code.

**Objectives covered**

| id | Objective |
|---|---|
| `ztna-netbird` | Deploy a WireGuard mesh with identity ACLs and a self-hosted control plane |

**SC-500 correspondence**: Microsoft Entra **Private Access** connector mesh — device-level private connectivity gated by identity. **Standards**: NIST SP 800-207 (micro-segmentation down to the peer; per-identity policy); default-deny between groups is D3FEND network isolation. Unrestricted mesh reach would be ATT&CK **T1021 (Remote Services)** / lateral movement — the group ACL is what denies it.

**Prerequisites**
- Terraform ≥1.6; a **self-hosted** NetBird control plane ($0, local), stood up from the official quickstart: <https://docs.netbird.io/selfhosted/selfhosted-quickstart> (the `getting-started-with-zitadel` docker-compose stack). This is an **external dependency** Part B relies on — pin the compose stack to a specific tagged NetBird release rather than tracking `latest`, so the provider/API surface doesn't drift under you mid-lab. You also need a PAT/service-user token, and the `netbird` client on two peers (e.g. two containers/VMs).
- Notes read: [`../domains/1-identity-governance/ztna-access-models.md`](../domains/1-identity-governance/ztna-access-models.md).

**Estimated time**: 2–3 h · $0 (local)

> **Directions-first.** Build the Terraform yourself from the steps below. A CI-validated **reference solution** lives in [`../lab-infra/ztna-netbird/`](../lab-infra/ztna-netbird/); use it to check your work, not to copy.

## Challenge

Build a self-hosted NetBird control plane and author the Terraform that turns it into a real ZTNA mesh: two identity groups (`admins`, `servers`), one enrollment key per group, and exactly one ACL policy — such that joining the mesh grants a peer **no reach at all** until a policy says otherwise.

Reach these observables:
- The admin peer can SSH the server peer (tcp/22) — nothing else is open between them.
- The server peer **cannot** initiate anything back to the admin peer — the policy is one-directional.
- A third peer enrolled into **neither** group can reach nothing, even though it's on the same encrypted mesh.

No solution below — that's in **Reference solution**, after Verification.

## Build it (guided)

### Part A — stand up the control plane
Bring up NetBird self-hosted (control plane + Zitadel IdP) via its docker-compose quickstart, then create a service-user PAT and drop it into `terraform.tfvars`. This is the **self-hostable** control plane that makes NetBird $0/local (unlike Tailscale's SaaS) — no cloud account, no seat licence.

**Your turn**: get the compose stack healthy and mint the PAT before touching Terraform — everything in Part B depends on a reachable `management_url` and a valid token.

### Part B — groups, keys, and the ACL (`ztna-netbird`)
Author Terraform (`netbirdio/netbird` provider) that builds the ACL from three ingredients — work out the resources and the wiring yourself:

1. **Groups are identity buckets, not subnets.** Create two `netbird_group` resources. Name them so a policy can reference them by role (e.g. `admins`, `servers`), not by IP.
2. **Setup keys enroll a device straight into its group.** Create two reusable `netbird_setup_key`s, one per group. Hint: the setup-key resource has an attribute that auto-assigns a peer to a group the moment it joins — find it in the `netbirdio/netbird` provider docs and use it so an admin laptop lands in `admins` and a server lands in `servers`, with no manual group-assignment step afterward.
3. **One policy, one rule — default-deny for everything else.** Write a single `netbird_policy` whose rule sources from the admin group and destinations the server group. Your turn to decide: which protocol and port satisfy "SSH only," and which `bidirectional` setting stops the server group from ever initiating back to admins? Get either wrong and the Challenge observables won't hold — either access is too narrow to work, or you've accidentally allowed lateral reach.

Run `terraform fmt`, `init`, `apply` once the policy is in place.

Then enroll each peer with its own setup key — pull the key straight out of the Terraform output rather than pasting it by hand, and point each peer's `netbird up` at your `management_url`. One peer takes the admin key, the other takes the server key.

## Verification
```bash
# From the ADMIN peer — allowed:
ssh user@<server-peer-netbird-ip>            # succeeds (policy: admins→servers:22)
# From the ADMIN peer — not allowed:
curl http://<server-peer-netbird-ip>:8080    # blocked (only :22 permitted)
# From the SERVER peer back to the admin — not allowed (bidirectional = false):
ssh user@<admin-peer-netbird-ip>             # blocked
```
- Both peers are on the same WireGuard mesh, yet reach is limited to exactly what the group ACL allows.
- Add a third peer to **neither** group → it can reach nothing — mesh membership ≠ access.
- Flip `bidirectional` or widen `ports` and re-apply to see the ACL change take effect — access is policy, versioned in code.

## Reference solution
Build it yourself first; check after. The CI-validated Terraform lives in [`../lab-infra/ztna-netbird/`](../lab-infra/ztna-netbird/):

- [`main.tf`](../lab-infra/ztna-netbird/main.tf) — the two `netbird_group`s (`admins`, `servers`); the two reusable `netbird_setup_key`s (`admin-laptops`, `server-fleet`) with `auto_groups` pinning each device to its group at enrollment; and the single `netbird_policy` rule (`sources = [admins]`, `destinations = [servers]`, `protocol = "tcp"`, `ports = ["22"]`, `bidirectional = false`). Everything not allowed is denied.
- [`up.sh`](../lab-infra/ztna-netbird/up.sh) / [`down.sh`](../lab-infra/ztna-netbird/down.sh) — `terraform init`/`apply`/`destroy` wrappers; `up.sh` prints the enrollment commands below after applying.
- [`terraform.tfvars.example`](../lab-infra/ztna-netbird/terraform.tfvars.example) / [`variables.tf`](../lab-infra/ztna-netbird/variables.tf) — the `management_url`, `netbird_token`, `ssh_port` inputs.

`terraform fmt`, `init`, `apply`. Enroll each peer with its key:
```bash
netbird up --management-url $MGMT --setup-key $(terraform output -raw admin_setup_key)   # on the admin peer
netbird up --management-url $MGMT --setup-key $(terraform output -raw server_setup_key)   # on the server peer
```

If your policy allows both directions or opens more than port 22, tighten `bidirectional` and `ports` and re-apply — the mesh doesn't self-correct; the policy is the only thing enforcing least privilege.

## Teardown
```bash
terraform destroy     # or ../lab-infra/ztna-netbird/down.sh
# remove enrolled peers from the dashboard; stop the compose stack
```

## What the exam asks
SC-500 frames private connectivity through **Entra Private Access**. The transferable concept: a mesh gives you *connectivity*, but zero trust means **identity-group policy decides reach**, default-deny, even for peers already "on" the mesh. Whether the tool is NetBird or Entra's connector mesh, being on the network is not being trusted.
