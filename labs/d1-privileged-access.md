# Lab d1: Privileged Access with Teleport

Prove that privileged access is *just-in-time, recorded, and approval-gated* — a short-lived certificate that expires on its own, a session you can replay byte-for-byte, and a role nobody holds until a second person signs off.

**Objectives covered**

| id | Objective |
|---|---|
| `pam-jit` | Implement just-in-time privileged access with short-lived credentials |
| `pam-session` | Configure session recording and audit for privileged sessions |
| `pam-approval` | Require approval workflows and role escalation for privileged roles *(walkthrough section)* |

**SC-500 correspondence**: Privileged Identity Management (PIM) — short-lived/just-in-time elevation (`pam-jit`), PIM audit history / access reviews (`pam-session`), PIM approval and eligible assignments (`pam-approval`).

**Prerequisites**
- [`lab-infra/pam`](../lab-infra/pam/) up (`./up.sh`), roles applied and user `alice` created (commands printed by `up.sh`)
- Notes read: [privileged-access.md](../domains/1-identity-governance/privileged-access.md)
- Tools for this lab: `tsh`, `tctl` (Teleport client/admin) — install per [`../TOOLS.md`](../TOOLS.md).
- `tsh` and `tctl` clients installed on the host ([Teleport installation](https://goteleport.com/docs/installation/))

**Estimated time**: 2–3 h · $0 (local)

## Challenge

Using the Teleport cluster from Prerequisites and the user `alice`, prove three properties of privileged access management — without ever touching a standing credential:

1. **JIT (`pam-jit`)** — obtain a short-lived certificate for `alice`, show its lifetime is bounded by a role setting (not a client flag), tighten that cap, and show the credential still works for a scoped resource and stops working the instant it expires — no manual revoke step.
2. **Session recording (`pam-session`)** — show sessions are recorded off the administered host, capture one, and replay it byte-for-byte. Be able to say why the structured audit log and the replayable recording are two different objects.
3. **Approval workflow (`pam-approval`, walkthrough)** — show `alice` is *eligible* for `db-admin` but holds *none* of its permissions until a **different** user approves a time-boxed request. Trace the separation-of-duties split between who can request and who can approve.

Reach the observables in **Verification** below before you look at the reference solution.

## Build it (guided)

### Part A — JIT short-lived certificates (`pam-jit`)

**Goal:** get a certificate for `alice`, find out where its lifetime comes from, then prove that changing that source — not a client setting — is what changes the cert.

- Log in as `alice` against the proxy `up.sh` exposed (`tsh login ...--user=alice`). Teleport mints an X.509 + SSH certificate; no static key is stored anywhere.
- Inspect what you got with `tsh status` and find the **"Valid until"** line. It should read ~1h out. That number isn't a `tsh` default — go find where it's actually configured: read the `db-oncall` role (`tctl get roles`, or open [`../lab-infra/pam/roles.yaml`](../lab-infra/pam/roles.yaml)) and locate the option that caps session length.
- **Your turn:** edit that cap down to `10m`, re-apply the role, `tsh logout` then log back in, and confirm `tsh status` now shows a 10-minute cert. If it still shows 1h, ask why before moving on — did the role actually re-apply, or are you looking at a cached credential?
- **Your turn:** use the certificate for something the role actually scopes you to (a Kubernetes call in the labelled namespace), then deliberately try a call outside that role's labels/namespace. It should be denied — confirm to yourself that the boundary is the label/namespace scope on the role, not a host allowlist somewhere.
- Let the short cert lapse (or force it with `tsh logout`), then repeat the same call through the Teleport kubeconfig. It should fail. Notice *why* it failed: not because anyone cleaned up a grant, but because the credential itself ran out — that's the JIT property an activation window is supposed to give you.

### Part B — Session recording & audit (`pam-session`)

**Goal:** confirm where the recording actually lives, then produce and replay one.

- Before trusting the control, verify it's configured the way you think: check the auth config (`tctl get cluster_networking_config`) for `session_recording`. It should read `proxy-sync`. Think through why recording *at the proxy* is a stronger guarantee than recording on the target node itself — what happens to node-side evidence if that node is the thing an attacker compromised?
- **Your turn:** start an interactive session through Teleport (`tsh kube exec -it <pod> -n oss500-apps -- /bin/sh`, or `tsh ssh` if you enrolled a node), run a few harmless commands, then exit.
- Find that session in the recordings list (`tctl sessions ls`, or the Web UI's *Session Recordings*) and note its session ID.
- Replay it (`tsh play <session-id>`). You should see the literal terminal stream, not a summary — that's the "who did what during their elevated window" artifact access reviews and IR depend on.
- Before moving to Part C, be able to state the difference between the two audit surfaces you just touched: the structured event log (`tctl sessions ls`, events like `cert.create`, `session.start`, `access_request.create` — the who/what/when you'd ship to a SIEM) versus the session recording (the replayable stream). They are different objects serving different jobs — don't conflate them.

### Part C — Access Requests / approval workflow (`pam-approval`) — WALKTHROUGH

*Full role-escalation flow needs two subjects (a requester and a distinct reviewer); documented here at exam depth and marked `walkthrough` in the tracker. You can drive it single-host by creating a second user.*

- Establish the baseline first: `alice` holds the `requester` role, which lists `request.roles: ['db-admin']` but grants **none** of db-admin's permissions. **Prove it** — as `alice`, attempt a `db-admin`-only action and watch it get denied.
- **Your turn:** request elevation (`tsh request create --roles=db-admin --reason=...`) with a reason a reviewer could actually act on. Check the request's state — it should sit **PENDING**, and `alice`'s effective permissions shouldn't have moved at all.
- Separation of duties needs a second subject who is *not* `alice`. Create a `bob` user carrying the `reviewer` role (not `requester`), and approve or deny the request **as bob** (`tctl request approve <request-id>` / `tctl request deny <request-id> --reason=...`). Ask yourself: what would break about this control if `bob` also held `requester`?
- Confirm the effect of approval: does `alice`'s *existing* session suddenly gain `db-admin`, or does something have to be reissued? Re-run the privileged action and see for yourself — then note what happens once the elevation's own `max_session_ttl` runs out.
- Go read `requester.allow.request.roles` next to `reviewer.allow.review_requests.roles` — that split *is* the guardrail against self-approval. **Your turn:** raise `thresholds.approve` to `2` in the role and reason through what a two-person rule changes operationally versus the single-approver baseline.

## Verification

- **JIT:** `tsh status` shows a certificate with a short **"Valid until"** (≤ 1 h); after it expires, the same `kubectl` call through Teleport is denied — access ended by expiry, not manual cleanup.
- **Recording:** `tsh play <session-id>` replays a privileged session captured at the proxy (off-host); `tctl sessions ls` shows the structured audit event for it.
- **Approval:** an access request shows **PENDING**, and the `db-admin` role appears in `tsh status` only **after** a *different* user approves it — eligible→approve→time-boxed active.

## Reference solution

Build it yourself first; check after. The lab roles themselves (`db-oncall`, `requester`, `reviewer`, `db-admin`) are already defined in [`../lab-infra/pam/roles.yaml`](../lab-infra/pam/roles.yaml) and applied by `up.sh` — the steps below are the exact sequence to drive them.

### Part A — JIT short-lived certificates (`pam-jit`)

1. Log in and get a certificate: `tsh login --insecure --proxy=localhost:3080 --user=alice`. Teleport authenticates you and mints an X.509 + SSH certificate — no static key is stored.
2. Inspect the credential's lifetime: `tsh status`. Read the **"Valid until"** line — under the `db-oncall` role it is ~1 h from now (`max_session_ttl: 1h`). This TTL *is* the JIT window: when it lapses, access is gone with nothing to revoke.
3. Confirm where the cap comes from: `kubectl -n oss500-identity exec deploy/teleport -- tctl get roles` and find `db-oncall` → `options.max_session_ttl: 1h` (see [`roles.yaml`](../lab-infra/pam/roles.yaml)). Change it to `10m`:
   ```yaml
   # in roles.yaml, db-oncall.spec.options
   max_session_ttl: 10m   # was 1h
   ```
   Re-apply with `kubectl -n oss500-identity exec -i deploy/teleport -- tctl create -f /dev/stdin < roles.yaml`, then `tsh logout && tsh login` again, and watch `tsh status` show a 10-minute cert.
4. Use the access: `tsh kube login oss500 && kubectl get pods -n oss500-apps` (scoped to `env: oss500`, `oss500-apps` only). Try a resource outside the role's labels/namespace and watch it be denied — the role scopes by label, not a host list.
5. Let a short cert expire (or `tsh logout`) and re-run `kubectl get pods` through the Teleport kubeconfig → it fails. Access ended by **expiry**, exactly as a PIM activation window closes automatically.

### Part B — Session recording & audit (`pam-session`)

6. Confirm recording mode: `kubectl -n oss500-identity exec deploy/teleport -- tctl get cluster_networking_config` and check the auth config shows `session_recording: proxy-sync` — the proxy records the session as it passes through, so the evidence lives **off** the administered host.
7. Start a recorded interactive session: `tsh kube exec -it <pod> -n oss500-apps -- /bin/sh` (or `tsh ssh` if you enrolled an SSH node). Run a few commands, then exit.
8. List recorded sessions: `kubectl -n oss500-identity exec deploy/teleport -- tctl sessions ls` (or the Web UI → *Session Recordings*). Note the session ID.
9. Replay it byte-for-byte: `tsh play <session-id>`. You are watching the exact terminal stream of a privileged session — the "who did what during their elevated window" evidence access reviews and IR depend on.
10. Distinguish the two audit surfaces: the **structured audit log** (`tctl sessions ls`, and events like `cert.create`, `session.start`, `access_request.create`) is the who/what/when you'd ship to a SIEM (Wazuh/OpenSearch in Domain 4); the **session recording** is the replayable stream. They are different objects with different jobs.

### Part C — Access Requests / approval workflow (`pam-approval`) — WALKTHROUGH

11. Baseline is *eligible, not active*: `alice` holds the `requester` role, which lists `request.roles: ['db-admin']` but grants **none** of db-admin's permissions. Prove it: `tsh kube login oss500` then attempt a `db-admin`-only action → denied.
12. Request elevation: `tsh request create --roles=db-admin --reason="INC-1234 hotfix"`. The request is **PENDING**; `alice` still has nothing.
13. Create a distinct reviewer and approve as them (separation of duties — the requester can't approve their own request): create user `bob` with the `reviewer` role —
    ```bash
    kubectl -n oss500-identity exec deploy/teleport -- \
      tctl users add bob --roles=reviewer --logins=readonly
    ```
    then `tctl request approve <request-id>` (or `tctl request deny <request-id> --reason=...`).
14. On approval, Teleport **re-issues alice's certificate with `db-admin` for a bounded window** (`max_session_ttl: 1h`). Re-run the privileged action → now allowed. When the window expires, it drops back to baseline.
15. Confirm the separation of duties in the roles: `requester` has `allow.request.roles`, `reviewer` has `allow.review_requests.roles` — two different subjects, no self-approval (see [`roles.yaml`](../lab-infra/pam/roles.yaml)). Raise `thresholds.approve` to `2` for a two-person rule:
    ```yaml
    # in roles.yaml, requester.spec.allow.request.thresholds
    thresholds:
      - approve: 2   # was 1 — now requires two reviewers
        deny: 1
    ```

If your role edits don't take effect, check you re-applied with `tctl create -f` against the running cluster (not just edited the file on disk) and that you logged out/in to pick up a fresh cert — a stale local credential will hide a real role change.

## Teardown

- `cd lab-infra/pam && ./down.sh`

## What the exam asks

- **Short-lived certificate TTL = the JIT enforcement.** "Eliminate standing admin access / time-bound elevation" → certs that expire, not a manual revoke step. The security property assumes there's **no direct path around the proxy**.
- **Proxy-side recording is tamper-resistant** because the evidence lives off the administered host; node-side recording is cheaper but a compromised target can alter it.
- **Audit events ≠ session recording**: the structured log (→ SIEM, drives access reviews) is distinct from the replayable session stream.
- **Eligible ≠ active**: a requestable baseline role grants nothing until an approved request re-issues the cert with the elevated role — a PIM eligible assignment activated via approval, time-boxed and audited.
- **Separation of duties**: `request.roles` (can ask) and `review_requests.roles` (can approve) are distinct; self-approval breaks the control. Approval thresholds = the approver list / two-person rule.
