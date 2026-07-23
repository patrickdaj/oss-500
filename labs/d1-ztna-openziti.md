# Lab d1: App-embedded Zero-Trust Overlay with OpenZiti *(beyond-blueprint)*

Reach a private app **by name over a mutual-TLS mesh** — with **zero listening ports on the underlay**, so there is nothing to port-scan or reach without an enrolled, authorized identity. The overlay ZTNA model (D1 `ztna-openziti`), as code.

**Objectives covered**

| id | Objective |
|---|---|
| `ztna-openziti` | Build an app-embedded zero-trust overlay with zero listening ports |

**SC-500 correspondence**: no direct Entra analog — OpenZiti pushes the trust boundary *into the application dial path*, further than Entra Private Access (which still fronts a network connector). **Standards**: NIST SP 800-207 (per-session, identity-based access to one resource); the "no inbound listener" property directly reduces the attack surface ATT&CK **T1046 (Network Service Discovery)** and **T1190 (Exploit Public-Facing Application)** depend on.

**Prerequisites**
- Terraform ≥1.6; a local controller + edge router via `ziti edge quickstart`; two `ziti-edge-tunnel` instances (client + host); a private backend app (any HTTP listener on `127.0.0.1:8080` works).
- Notes read: [`../domains/1-identity-governance/ztna-access-models.md`](../domains/1-identity-governance/ztna-access-models.md).
- Tools for this lab: `terraform`, `ziti`, `ziti-edge-tunnel` — install per [`../TOOLS.md`](../TOOLS.md).

**Estimated time**: 2–3 h · $0 (local)

> **Directions-first.** Build the Terraform yourself from the steps below — that's the learning. A CI-validated **reference solution** lives in [`../lab-infra/ztna-openziti/`](../lab-infra/ztna-openziti/); use it to check your work, not to copy.

## Challenge

Build the Terraform (`netfoundry/ziti` provider) for an app-embedded zero-trust overlay: a **client** identity that can dial a private app **by an overlay-only name**, a **host** identity that binds/hosts it, and policies that split those two capabilities so neither identity can do the other's job. Reach these observables:

- From the enrolled client tunneler, `curl http://private-app.ziti:8080/` succeeds — the app is reached **by overlay name**, resolved and encrypted end-to-end inside Ziti.
- An `nmap -p 8080` scan of the host machine's **underlay** IP shows the port **NOT open to the network** — the hosting tunneler only dials *out* to the edge router; there is nothing to discover or exploit (`T1046`/`T1190`).
- An identity **without** the `#client` role — or a tunneler that was never enrolled at all — **cannot dial** the service. Dial is refused, proving least privilege rather than assuming it.

No solution below — that's what you're building.

## Build it (guided)

### Part A — the overlay identities (`ztna-openziti`)
Start the fabric: `ziti edge quickstart` (an all-in-one controller + edge router on `127.0.0.1`).

**Your turn.** In Terraform, define two `ziti_identity` resources: one that will *dial* the service, one that will *bind/host* it. Each identity needs a `role_attributes` list — this is how the policies in Part C will select "which identities may do what" *by role*, not by IP or hostname.
- Hint: pick role-attribute names that describe the *capability*, not the machine (e.g. something that reads as "this one is a client" vs. "this one hosts the app").
- Each identity resource exposes a one-time (OTT) `enrollment_token` — you'll need it later to enroll the real `ziti-edge-tunnel` processes. Think about which Terraform attribute on `ziti_identity` gives you that token, and whether it should be marked `sensitive`.

### Part B — the service and its configs
**Your turn.** You need three resources:
1. A `ziti_intercept_v1_config` — the address the client dials. This is the **overlay-only** name (e.g. something like `private-app.ziti`) — it lives *inside* Ziti and is never a real DNS record the underlay resolves. What protocol and port does the client expect to reach?
2. A `ziti_host_v1_config` — where the *hosting* tunneler actually forwards a dialed connection once it arrives (your real backend, e.g. `127.0.0.1:8080`).
3. A `ziti_service` that bundles both configs together and carries its own `role_attributes` (this is what Part C's policies will target).
- Why two separate configs instead of one? One config describes what the *client* asks for; the other describes where the *host* actually sends the traffic. Keeping them separate is what lets the overlay name diverge from the real backend address — the client never needs to know `127.0.0.1:8080` exists.

### Part C — least-privilege authorization
**Your turn.** Write two `ziti_service_policy` resources:
- A **Dial** policy that lets only your client-role identities dial only your private-app-role service.
- A **Bind** policy that lets only your host-role identities bind that same service.
- Question to answer before you write these: what breaks if you give the client identity *both* dial and bind roles by mistake? Trace through why splitting Dial and Bind into separate policies (rather than one policy granting both) is what actually enforces "the client can only dial, the host can only bind."

Then add the router-reachability pieces: a `ziti_service_edge_router_policy` and a `ziti_edge_router_policy`, both scoped so your service and your two identities can actually use an edge router (for a single local router, think about what a wide-open `#all` role means here versus in a multi-router production fabric).

**Bring it up.** Run `terraform fmt`, `init`, `apply`. Then enroll the two tunnelers using the enrollment-token outputs you defined in Part A — pull each token with `terraform output -raw <your_token_output_name>` into a `.jwt` file, and run `ziti-edge-tunnel enroll -j <file>.jwt` for both the host and the client. If you didn't already, name your outputs so this step is unambiguous about which token belongs to which identity.

**Before you check the reference solution**, run the Verification steps below yourself — including the negative test (un-enrolled or wrong-role dial). If it fails, the fix is almost always in Part C's policy scoping, not the identities or configs.

## Verification
```bash
# From the client tunneler host — dial the app by its OVERLAY name:
curl http://private-app.ziti:8080/
# On the underlay, prove there is nothing to reach without the overlay:
nmap -p 8080 <host-machine-underlay-ip>   # 8080 is NOT open to the network
```
- The client reaches the app **by overlay name** — resolved and encrypted end-to-end inside Ziti.
- A scan of the underlay shows **no listening port** for the service — the host tunneler makes only *outbound* connections to the router (dial-out hosting).
- An identity **without** the `#client` role (or an un-enrolled machine) **cannot** dial — least privilege, proven in Domain 5.

## Reference solution
Build it yourself first; check after. The complete, CI-validated Terraform lives in [`../lab-infra/ztna-openziti/`](../lab-infra/ztna-openziti/):
- [`main.tf`](../lab-infra/ztna-openziti/main.tf) — the two `ziti_identity`s (`#client` / `#host-app`), the `ziti_intercept_v1_config` + `ziti_host_v1_config` bundled into `ziti_service`, the Dial/Bind `ziti_service_policy` pair, and the router-reachability policies. Every resource is commented with the same "why" from Part A–C above.
- [`variables.tf`](../lab-infra/ztna-openziti/variables.tf) / [`terraform.tfvars.example`](../lab-infra/ztna-openziti/terraform.tfvars.example) — the mgmt-API, backend, and intercept-address inputs.
- [`up.sh`](../lab-infra/ztna-openziti/up.sh) — `terraform init`/`apply`, then prints the exact `terraform output -raw ... | ziti-edge-tunnel enroll -j ...` commands for both tunnelers.
- [`down.sh`](../lab-infra/ztna-openziti/down.sh) — `terraform destroy` plus cleanup of the local `.jwt` files.

If your Terraform applies cleanly but the negative test (un-enrolled/wrong-role dial) still succeeds, compare your Dial/Bind `ziti_service_policy` `identityroles`/`serviceroles` against `main.tf` line-by-line — that scoping is where least privilege actually lives, not in the identities themselves.

## Teardown
```bash
terraform destroy     # or ../lab-infra/ztna-openziti/down.sh
# stop the `ziti edge quickstart` controller/router
```

## What the exam asks
SC-500 has no exact analog — the transferable idea is the ZTNA endgame: **remove the inbound listener entirely**. Where Entra Private Access still terminates on a connector, OpenZiti dials the app from inside an identity-bound mesh, so `T1046`/`T1190`-style discovery-and-exploit has no surface to work against. Recognize the pattern: per-session, identity-based, **and no standing attack surface**.
