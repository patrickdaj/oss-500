# ZTNA Authorization Testing — prove least privilege holds *(beyond-blueprint)*

Domain 1 built five zero-trust access models (`d1-ztna`: Boundary+Vault, OpenZiti, Pomerium, NetBird, plus Teleport/SPIFFE ✅). A broker that can't *deny* is not zero trust. This track attacks each one the way [NIST SP 800-207](https://csrc.nist.gov/pubs/sp/800/207/final) demands you validate a PEP: **attempt access you are not authorized for, and confirm it is refused.**

## The authz tests, per model
| Model (lab) | Unauthorized attempt | Expected result (the proof) |
|---|---|---|
| **Boundary+Vault** (`ztna-boundary`) | authenticate as `appuser`, try `authorize-session` on a target you have **no role** for; try to reach the host's IP **directly**, bypassing the worker | session **denied**; no network route to the host at all (the worker is the only path) |
| **OpenZiti** (`ztna-openziti`) | from an **un-enrolled** machine, or an identity without `#client`, dial the service; port-scan the underlay | dial **refused**; underlay shows **no listening port** — nothing to hit |
| **Pomerium** (`ztna-pomerium`) | reach the route unauthenticated; then as a valid user **outside** the policy domain; try to reach `internal-app` directly | 302→IdP, then **403**; app has no ingress of its own |
| **NetBird** (`ztna-netbird`) | from a peer in **no** group, reach a server; from `servers`, initiate **back** to `admins`; hit a non-allowed port | all **blocked** — mesh membership ≠ access; `bidirectional=false` holds |

## Method (the four steps, ZTNA flavor)
The four steps are defined canonically in [`purple-team.md`](purple-team.md); here in ZTNA flavor:
1. **Build** — the broker is up from its D1 lab.
2. **Name** — the property under test: *authentication ≠ authorization*, *no standing network position*, *default-deny*. (800-207 §2 tenets; the negative test is the validation ATT&CK **T1078 / T1021** would exploit if it failed.)
3. **Fire** — run the unauthorized attempt from the table **against your local broker only**.
4. **Confirm** — access is **denied** and, ideally, the denial is **logged** (feed it to Wazuh from D4 to close the loop: attack → deny → alert).

## Why "deny" is the whole point
Every other domain proves a control *does* something; ZTNA validation proves a control *refuses* something. The failure mode you're hunting is the quiet one — an over-broad Boundary role, a Pomerium policy that allows the wrong domain, a NetBird rule left `bidirectional=true`. Those don't crash; they silently over-grant. Only the negative test surfaces them.

## Standards
Offense: authz-bypass attempts (mapped to ATT&CK T1078 Valid Accounts / T1021 Remote Services where relevant). Defense: **NIST SP 800-207 / 207A** PEP enforcement; **[CISA ZTMM v2.0](https://www.cisa.gov/zero-trust-maturity-model)** "continually verify." Close the loop with the D4 SIEM so denials are observable.

## Self-check
1. For each of the four brokers, state the one unauthorized action whose denial proves the model.
2. Why is an over-granted policy more dangerous than an outage, and which test catches it?
3. How would you wire a Boundary session-denied event into Wazuh so the refusal is alertable?
