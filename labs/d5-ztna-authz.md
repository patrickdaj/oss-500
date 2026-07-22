# Lab d5: ZTNA Authorization Testing *(beyond-blueprint)*

Attack each zero-trust broker from Domain 1 the way NIST 800-207 says you must validate a PEP: **attempt access you are not authorized for, and confirm it's denied** (and, ideally, logged). A broker that can't deny is not zero trust.

**Objectives covered**

| id | Objective |
|---|---|
| `av-ztna-authz` | Unauthorized-access attempts against Boundary/OpenZiti/Pomerium/NetBird; confirm denial + logging |

**SC-500 correspondence**: beyond SC-500. **Standards**: NIST SP 800-207/207A (PEP enforcement), CISA ZTMM (continually verify), ATT&CK T1078 (Valid Accounts) / T1021 (Remote Services) — the behaviors a broken broker would enable. Defensive counterpart: the D1 `d1-ztna` labs.

**Prerequisites**
- At least one ZTNA broker up from Domain 1: [`d1-ztna-boundary`](d1-ztna-boundary.md), [`d1-ztna-openziti`](d1-ztna-openziti.md), [`d1-ztna-pomerium`](d1-ztna-pomerium.md), [`d1-ztna-netbird`](d1-ztna-netbird.md).
- Optional: Wazuh from D4 to prove denials are alertable.
- Notes read: [`../domains/5-offensive-validation/ztna-authz.md`](../domains/5-offensive-validation/ztna-authz.md).

**Estimated time**: 2 h · $0 (local) · **your own brokers only**

## Challenge

For **each broker you stood up in Domain 1**, reach one observable per unauthorized attempt: a request that should never succeed, provably denied by the PEP before it reaches the target.

- **Boundary+Vault**: as an authenticated but *unauthorized* identity, reach a target you hold no role for — expect the broker itself to refuse authorization, and expect the target's network path to be unreachable by any other route.
- **OpenZiti**: from an identity that is either **un-enrolled** or missing the required app-data attribute, try to reach the private service — expect the dial to be refused, and expect the underlay to expose **no** listening port to scan.
- **Pomerium**: reach the app **anonymously** — expect a redirect to the IdP, not the app. Then authenticate as a user **outside** the allowed domain — expect a `403`. Then check whether the app has any network path that doesn't go through Pomerium at all.
- **NetBird**: from a peer with **no** group membership, from a `servers` peer trying to reach **back** into `admins`, and from `admins` hitting a **non-SSH** port on a server — each should be blocked by policy, not by luck.

No solution here — figure out the exact command/tool for each attempt yourself before checking the reference.

## Build it (guided)

For every broker, the method is the same — this is the NIST 800-207 PEP-validation loop: **attempt access you are not authorized for, confirm it's refused, and record the exact denial.** Work through each broker you have running.

### Boundary+Vault (`ztna-boundary`)
1. Authenticate to Boundary as a real but limited identity (e.g. `appuser`). What credential type does Boundary expect, and where does it come from (hint: Vault issued it in `d1-ztna-boundary`)?
2. Pick a target you were **deliberately not** granted a role for, and attempt to connect through Boundary. What do you expect the broker to say — and *before* that, what should never happen (a packet reaching the target host)?
3. Now try to reach that same target **directly**, bypassing Boundary entirely. Why should this fail on its own, independent of any Boundary decision? What does that prove about the worker's position in the network?
4. Record the exact denial message from each attempt.

### OpenZiti (`ztna-openziti`)
1. From a machine that is either not enrolled in the OpenZiti overlay, or whose identity lacks the attribute the service policy requires, attempt to dial the private service. What should the client report?
2. Separately, run a port scan against the **underlay** IP (the real host, not the Ziti overlay address). Why should this come back empty — what security property does a "dark" underlay give you that a traditional VPN/firewall rule doesn't?
3. Record both results.

### Pomerium (`ztna-pomerium`)
1. Hit the app's URL with no session at all. What should happen instead of reaching the app?
2. Authenticate through the IdP as a user who is real but **outside** the domain/group Pomerium's policy allows. What HTTP status do you expect back, and where is that decision enforced (proxy vs. app)?
3. Try to reach the backend app on its own service port, skipping Pomerium's ingress path completely (think about how you'd expose a ClusterIP service directly for testing). Does the app have any ingress of its own to exploit if Pomerium were bypassed?
4. Record the redirect, the `403`, and your conclusion about the app's own exposure.

### NetBird (`ztna-netbird`)
1. From a peer that belongs to **no** NetBird group, attempt to reach a server peer. Expected outcome?
2. From a `servers` peer, attempt an SSH connection **back** to an `admins` peer. NetBird's ACLs can be directional — what setting controls whether this is allowed, and what should it be set to here?
3. From an `admins` peer, attempt to hit a port on a server that **isn't** the SSH port the policy grants. Expected outcome?
4. Record all three denials.

## Verification
- Every unauthorized attempt is **denied**. Record the exact denial (message / refused connection).
- **Close the loop**: forward at least one denial (e.g. a Boundary session-denied event) into **Wazuh** and confirm it raises an alert — attack → deny → detect.
- Deliberately **over-grant** one policy (add a role / flip `bidirectional`), re-run, watch the previously-denied action succeed, then revert — this proves your test actually distinguishes allow from deny.

## Reference solution
Build it yourself first; check after. The commands below and their expected results are the exact bypass attempts referenced in [`../lab-infra/offense/README.md`](../lab-infra/offense/README.md) (ZTNA track: curl/ssh/nmap, no install required).

### Boundary+Vault (`ztna-boundary`)
```bash
boundary authenticate password -login-name appuser
boundary connect ssh -target-id <a-target-you-have-NO-role-for>   # expect: authorization denied
ssh user@<target-host-ip>                                         # expect: no route — the worker is the only path
```

### OpenZiti (`ztna-openziti`)
- From an **un-enrolled** machine (or an identity lacking `#client`), dial the service → **refused**.
- `nmap -p 8080 <underlay-ip>` → **no listening port** (nothing to exploit).

### Pomerium (`ztna-pomerium`)
```bash
curl -I https://app.localtest.me            # expect: 302 -> Keycloak (no anonymous access)
# authenticate as a user OUTSIDE the allowed domain -> expect: 403
kubectl port-forward svc/internal-app 9999  # then curl :9999 -> app has no ingress of its own
```

### NetBird (`ztna-netbird`)
- From a peer in **no** group → reach a server → **blocked**.
- From a `servers` peer → SSH **back** to an `admins` peer → **blocked** (`bidirectional=false`).
- From `admins` → hit a **non-22** port on a server → **blocked**.

### Per-broker expected-result map
| Broker | Unauthorized attempt | Expected result |
|---|---|---|
| Boundary+Vault | Connect to target with no role | `authorization denied` |
| Boundary+Vault | Direct SSH to target, bypassing worker | no route |
| OpenZiti | Dial from un-enrolled/attribute-missing identity | refused |
| OpenZiti | `nmap` the underlay IP | no listening port |
| Pomerium | Anonymous request | `302` to Keycloak |
| Pomerium | Authenticated, wrong domain | `403` |
| Pomerium | Direct port-forward to backend service | app has no ingress of its own |
| NetBird | No-group peer → server | blocked |
| NetBird | `servers` peer → SSH back to `admins` | blocked (`bidirectional=false`) |
| NetBird | `admins` → non-22 port on server | blocked |

If a denial doesn't fire, check the policy first (missing default-deny, an over-broad role/group) before assuming the broker is broken — see the over-grant check in Verification.

## Teardown
Bring down each broker via its D1 `down.sh`. Revert any policy you loosened for the over-grant demo.

## Honesty note
The value here is catching **silent over-grant** — the failure that doesn't crash. Report each broker's denial as executed evidence; label brokers you didn't stand up as directions.
