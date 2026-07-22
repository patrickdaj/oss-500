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

**Estimated time**: 2–3 h · $0 (local)

> **Directions-first.** Build the Terraform yourself from the steps below — that's the learning. A CI-validated **reference solution** lives in [`../lab-infra/ztna-openziti/`](../lab-infra/ztna-openziti/); use it to check your work, not to copy.

## Steps — build it yourself

### Part A — the overlay identities (`ztna-openziti`)
Start the fabric: `ziti edge quickstart` (an all-in-one controller + edge router on `127.0.0.1`). Then author Terraform (`netfoundry/ziti` provider) that creates:
1. Two `ziti_identity`s — a **client** (`role_attributes = ["client"]`) that will *dial*, and a **host** (`role_attributes = ["host-app"]`) that will *bind/host* the service. Each yields a one-time (OTT) `enrollment_token`.

### Part B — the service and its configs
2. A `ziti_intercept_v1_config` — the **overlay-only** address the client dials (e.g. `private-app.ziti`). This name lives *inside* Ziti; the underlay never sees it.
3. A `ziti_host_v1_config` — where the hosting tunneler forwards a dialed connection (the real backend `127.0.0.1:8080`).
4. A `ziti_service` bundling both configs, with `role_attributes = ["private-app"]`.

### Part C — least-privilege authorization
5. A **Dial** `ziti_service_policy` (`identityroles = ["#client"]`, `serviceroles = ["#private-app"]`) and a **Bind** `ziti_service_policy` (`identityroles = ["#host-app"]`). The client may *only* dial; the host may *only* bind — split by policy.
6. A `ziti_service_edge_router_policy` and `ziti_edge_router_policy` (`edgerouterroles = ["#all"]`) so the service and identities can use the router.

`terraform fmt`, `init`, `apply`. Then enroll the two tunnelers with the emitted tokens:
```bash
terraform output -raw host_enrollment_token   > host.jwt   && ziti-edge-tunnel enroll -j host.jwt
terraform output -raw client_enrollment_token > client.jwt && ziti-edge-tunnel enroll -j client.jwt
```

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

## Teardown
```bash
terraform destroy     # or ../lab-infra/ztna-openziti/down.sh
# stop the `ziti edge quickstart` controller/router
```

## What the exam asks
SC-500 has no exact analog — the transferable idea is the ZTNA endgame: **remove the inbound listener entirely**. Where Entra Private Access still terminates on a connector, OpenZiti dials the app from inside an identity-bound mesh, so `T1046`/`T1190`-style discovery-and-exploit has no surface to work against. Recognize the pattern: per-session, identity-based, **and no standing attack surface**.
