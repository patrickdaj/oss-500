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

## Steps — one negative test per broker

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

## Verification
- Every unauthorized attempt is **denied**. Record the exact denial (message / refused connection).
- **Close the loop**: forward at least one denial (e.g. a Boundary session-denied event) into **Wazuh** and confirm it raises an alert — attack → deny → detect.
- Deliberately **over-grant** one policy (add a role / flip `bidirectional`), re-run, watch the previously-denied action succeed, then revert — this proves your test actually distinguishes allow from deny.

## Teardown
Bring down each broker via its D1 `down.sh`. Revert any policy you loosened for the over-grant demo.

## Honesty note
The value here is catching **silent over-grant** — the failure that doesn't crash. Report each broker's denial as executed evidence; label brokers you didn't stand up as directions.
