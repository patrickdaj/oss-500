# Zero-Trust Access — five models, one principle *(beyond-blueprint)*

Zero-trust network access (ZTNA) replaces "get on the network, then be trusted" with **broker one connection to one resource, per session, by identity, with nothing exposed inbound**. This section builds that idea five ways on open source — each a different *place to put the trust boundary* — all Terraform-automated. It extends Domain 1 (access); the network-layer zero trust (default-deny NetworkPolicy, mesh mTLS) lives in Domain 2.

**Standard:** [NIST SP 800-207](https://csrc.nist.gov/pubs/sp/800/207/final) defines the model — a **Policy Decision Point** (decides) and **Policy Enforcement Point** (sits in the path, brokers the session to one resource). [CISA ZTMM v2.0](https://www.cisa.gov/zero-trust-maturity-model) is the maturity frame. **SC-500 analog:** Microsoft Entra **Private Access** (Global Secure Access) + PIM.

## The five models

| Model | OSS tool | What's distinctive | Azure analog |
|---|---|---|---|
| **Broker / bastion** | **Teleport** ✅, **Boundary + Vault** | authenticate → authorize a *session* → a worker proxies it; Vault **injects** an ephemeral credential the user never sees | Entra Private Access + PIM |
| **App-embedded overlay** | **OpenZiti** | the app is dialed by name over a mutual-TLS mesh — **zero listening ports on the underlay**, nothing to scan | (no direct Azure analog) |
| **Identity-aware reverse proxy** | **Pomerium** | per-request identity+context policy in front of an internal web app (BeyondCorp) | Entra Private Access / App Proxy |
| **WireGuard mesh** | **Netbird** | device-level encrypted mesh with identity ACLs; self-hosted control plane | Entra Private Access (connector mesh) |
| **Workload-identity substrate** | **SPIFFE/SPIRE** ✅ | cryptographic identity for *services*, so broker/overlay/proxy policies bind to workload identity, not IP | Workload Identity Federation |

Teleport (broker) and SPIFFE/SPIRE (substrate) are already covered in this domain — see [`privileged-access.md`](privileged-access.md) and the workload-identity lab. The new labs add Boundary+Vault, OpenZiti, Pomerium, and Netbird.

## Why five, not one
Each puts the boundary somewhere different — a self-hosted broker (Boundary), the application itself (OpenZiti), an edge proxy (Pomerium), or a device mesh (Netbird). A cloud/AI security engineer should recognize the *pattern* (PDP/PEP + per-session identity + no inbound exposure) and pick the model that fits the resource: SSH/DB → broker; internal web app → proxy; app-to-app → overlay; roaming fleet → mesh.

## As code
Every lab deploys via **Terraform** where a provider exists — Boundary, Vault, and Netbird have official providers; OpenZiti has a community edge provider; Pomerium is a Terraform-wrapped Helm release. Deploy → verify identity-based access to one resource with no broader reach → tear down. No cloud account.

## Validate it *(purple team)*
Each broker is proven in Domain 5: attempt to reach a resource you're **not** authorized for and confirm it's denied — the ZTNA authz test. A model that can't deny is not zero trust.

## Self-check
1. Define PDP vs PEP and place Boundary's controller/worker in each.
2. For (a) SSH to private hosts, (b) an internal web app for contractors, (c) app-to-app with zero attack surface — pick a model and justify it.
3. Why does credential *injection* (Boundary+Vault) beat credential *brokering*, and what makes the secret ephemeral?
