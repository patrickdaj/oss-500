# Lab d1: WireGuard Mesh with Identity ACLs using NetBird *(beyond-blueprint)*

Build a device-level encrypted **WireGuard mesh** with a **self-hosted control plane**, where access between peers is governed by **identity group ACLs, not network position** — joining the mesh grants no lateral reach on its own. The mesh ZTNA model (D1 `ztna-netbird`), as code.

**Objectives covered**

| id | Objective |
|---|---|
| `ztna-netbird` | Deploy a WireGuard mesh with identity ACLs and a self-hosted control plane |

**SC-500 correspondence**: Microsoft Entra **Private Access** connector mesh — device-level private connectivity gated by identity. **Standards**: NIST SP 800-207 (micro-segmentation down to the peer; per-identity policy); default-deny between groups is D3FEND network isolation. Unrestricted mesh reach would be ATT&CK **T1021 (Remote Services)** / lateral movement — the group ACL is what denies it.

**Prerequisites**
- Terraform ≥1.6; a **self-hosted** NetBird control plane ($0, local) — the official `getting-started-with-zitadel` docker-compose quickstart; a PAT/service-user token; the `netbird` client on two peers (e.g. two containers/VMs).
- Notes read: [`../domains/1-identity-governance/ztna-access-models.md`](../domains/1-identity-governance/ztna-access-models.md).

**Estimated time**: 2–3 h · $0 (local)

> **Directions-first.** Build the Terraform yourself from the steps below. A CI-validated **reference solution** lives in [`../lab-infra/ztna-netbird/`](../lab-infra/ztna-netbird/); use it to check your work, not to copy.

## Steps — build it yourself

### Part A — stand up the control plane
Bring up NetBird self-hosted (control plane + Zitadel IdP) via its docker-compose quickstart. Create a service-user PAT → `terraform.tfvars`. This is the **self-hostable** control plane that makes NetBird $0/local (unlike Tailscale's SaaS).

### Part B — groups, keys, and the ACL (`ztna-netbird`)
Author Terraform (`netbirdio/netbird` provider) that creates:
1. Two `netbird_group`s: `admins` and `servers` — identity buckets, not subnets.
2. Two reusable `netbird_setup_key`s with `auto_groups` pinning each device to its group at enrollment (`admin-laptops` → admins, `server-fleet` → servers).
3. One `netbird_policy` with a rule: `sources = [admins]`, `destinations = [servers]`, `protocol = "tcp"`, `ports = ["22"]`, `bidirectional = false`. Everything not allowed is denied.

`terraform fmt`, `init`, `apply`. Enroll each peer with its key:
```bash
netbird up --management-url $MGMT --setup-key $(terraform output -raw admin_setup_key)   # on the admin peer
netbird up --management-url $MGMT --setup-key $(terraform output -raw server_setup_key)   # on the server peer
```

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

## Teardown
```bash
terraform destroy     # or ../lab-infra/ztna-netbird/down.sh
# remove enrolled peers from the dashboard; stop the compose stack
```

## What the exam asks
SC-500 frames private connectivity through **Entra Private Access**. The transferable concept: a mesh gives you *connectivity*, but zero trust means **identity-group policy decides reach**, default-deny, even for peers already "on" the mesh. Whether the tool is NetBird or Entra's connector mesh, being on the network is not being trusted.
