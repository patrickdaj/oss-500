# Zero-Trust Access — five models, one principle *(beyond-blueprint)*

Zero-trust network access (ZTNA) replaces "get on the network, then be trusted" with **broker one connection to one resource, per session, by identity, with nothing exposed inbound**. This section builds that idea five ways on open source — each a different *place to put the trust boundary* — all Terraform-automated. It extends Domain 1 (access); the network-layer zero trust (default-deny NetworkPolicy, mesh mTLS) lives in Domain 2.

**Standard:** [NIST SP 800-207](https://csrc.nist.gov/pubs/sp/800/207/final) defines the model — a **Policy Decision Point** (decides) and **Policy Enforcement Point** (sits in the path, brokers the session to one resource). [CISA ZTMM v2.0](https://www.cisa.gov/zero-trust-maturity-model) is the maturity frame. **SC-500 analog:** Microsoft Entra **Private Access** (Global Secure Access) + PIM. `[depth]`

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

## Object models: what each lab's Terraform actually creates
The table above names the pattern; it doesn't teach the objects. Each model below is a **chain** — build it top-down, in this order, and every later object refers back to one earlier in the chain rather than to an IP.

### Boundary — scope → auth-method → host-catalog → host-set → target → role/grant
Boundary organizes access under an identity-aware hierarchy, not a flat network: an `org` **scope** contains a `project` **scope**; inside the project, an **auth-method** (`password` for the lab) plus an **account** authenticates a **user** — the identity every later grant hangs off. Resources are modeled by identity, not address: a **host-catalog** (static, or plugin-backed for cloud inventories) holds **host** entries whose real address lives only on the host object, resolved into a **host-set**; a **target** (protocol + port, e.g. `tcp`/22) attaches to that host-set and is what a session actually connects to. A **role** then grants a user a specific **grant string** on that target — for a broker session, `authorize-session` and nothing else. Walk the chain forward to find what a subject can reach (`role → target → host-set → host`); walk it backward to prove nothing beyond the granted target is exposed.

> **Credential injection is a Domain 2 sliver, front-loaded.** The lab pairs this chain with a Vault `credential-store`/`credential-library` attached to the target's `injected_application_credential_source_ids`, so the SSH credential is placed into the session by the worker rather than handed to the user. You don't need Vault fluency for this note — the credential objects sit downstream of the target, and the full secrets engine is taught in [`secrets-management.md`](../2-secrets-data-networking/secrets-management.md) (Domain 2, `vault-*`).

**Resources:**
- [Terraform Registry — `hashicorp/boundary` provider: `boundary_target` resource (host-set attachment, default port, where grants ultimately apply)](https://registry.terraform.io/providers/hashicorp/boundary/latest/docs/resources/target) `[required-for-lab]` (~15 min)

### OpenZiti — identity → service → policy → enrollment
OpenZiti has no network-reachable target at all — the chain is entirely identity- and policy-based. An **identity** carries `role_attributes` (e.g. `#client`, `#host-app`) and enrolls via a one-time JWT into a real `ziti-edge-tunnel` process. A **service** bundles two configs: an **intercept config** (the overlay-only name/port the client dials, e.g. `private-app.ziti:8080` — never a real DNS record) and a **host config** (the real backend address, e.g. `127.0.0.1:8080`, that the hosting identity forwards a dialed connection to) — keeping them separate is what lets the overlay name diverge from the real address. A **service policy** of type **Dial** or **Bind** — never both in the same policy — selects, by role attribute, which identities may ask to connect and which may accept connections for that service; splitting Dial from Bind is what stops a client identity from also being able to host. An **edge-router policy** and **service-edge-router policy** grant the identities and the service reachability through an edge router at all — without them, an otherwise-correct Dial/Bind pair still can't route.

**Resources:**
- [Terraform Registry — `netfoundry/ziti` provider: `ziti_service_policy` resource (Dial vs Bind, `identityroles`/`serviceroles`)](https://registry.terraform.io/providers/netfoundry/ziti/latest/docs/resources/service_policy) `[required-for-lab]` (~15 min)

### Pomerium — OIDC client → route → policy
Pomerium's model is flatter but layered: Pomerium is itself an OIDC **client** of the IdP (registered with a redirect URI before it can authenticate anyone else), a **route** (`from` a public hostname, `to` an internal Service's cluster-DNS name) is the only path in — there is no ingress on the app itself — and a **policy** attached to that route is the per-request authorization, an `allow.and`/`allow.or` expression (e.g. `domain.is == var.allowed_domain`) evaluated against the identity the `authenticate` service resolved via OIDC on *this* request, not once at login. A valid login and an allowed route are two separate gates: unauthenticated traffic gets a redirect to the IdP, authenticated-but-out-of-policy traffic gets a 403 from the route's policy.

**Resources:**
- [Artifact Hub — `pomerium/pomerium` Helm chart (the `values` schema: `authenticate.idp`, `config.routes`, route `policy`)](https://artifacthub.io/packages/helm/pomerium/pomerium) `[required-for-lab]` (~15 min)

### NetBird — group → setup-key → policy
NetBird separates *joining the mesh* from *being allowed to talk on it*. A **group** is an identity bucket (`admins`, `servers`), not a subnet. A **setup-key** is a reusable enrollment token that, via its auto-group attribute, drops a peer straight into a group the moment it joins — no manual assignment step. A **policy** is the only thing granting reach: one rule names a source group, a destination group, a protocol/port set, and a `bidirectional` flag — mesh membership by itself grants nothing until a policy says otherwise, and a peer in neither group can reach nothing even though it shares the same encrypted WireGuard mesh.

**Resources:**
- [Terraform Registry — `netbirdio/netbird` provider: `netbird_policy` resource (rule sources/destinations, protocol/ports, `bidirectional`)](https://registry.terraform.io/providers/netbirdio/netbird/latest/docs/resources/policy) `[required-for-lab]` (~15 min)

## As code
Every lab deploys via **Terraform** where a provider exists — Boundary, Vault, and Netbird have official providers; OpenZiti has a community edge provider; Pomerium is a Terraform-wrapped Helm release. Deploy → verify identity-based access to one resource with no broader reach → tear down. No cloud account.

## Validate it *(purple team)*
Each broker is proven in Domain 5: attempt to reach a resource you're **not** authorized for and confirm it's denied — the ZTNA authz test. A model that can't deny is not zero trust.

## Self-check
1. Define PDP vs PEP and place Boundary's controller/worker in each.
2. For (a) SSH to private hosts, (b) an internal web app for contractors, (c) app-to-app with zero attack surface — pick a model and justify it.
3. Why does credential *injection* (Boundary+Vault) beat credential *brokering*, and what makes the secret ephemeral?
