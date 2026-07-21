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
- `tsh` and `tctl` clients installed on the host ([Teleport installation](https://goteleport.com/docs/installation/))

**Estimated time**: 2–3 h · $0 (local)

## Steps

### Part A — JIT short-lived certificates (`pam-jit`)

1. Log in and get a certificate: `tsh login --insecure --proxy=localhost:3080 --user=alice`. Teleport authenticates you and mints an X.509 + SSH certificate — no static key is stored.
2. Inspect the credential's lifetime: `tsh status`. Read the **"Valid until"** line — under the `db-oncall` role it is ~1 h from now (`max_session_ttl: 1h`). This TTL *is* the JIT window: when it lapses, access is gone with nothing to revoke.
3. Confirm where the cap comes from: `kubectl -n oss500-identity exec deploy/teleport -- tctl get roles` and find `db-oncall` → `options.max_session_ttl: 1h`. Change it to `10m`, re-apply, `tsh logout && tsh login` again, and watch `tsh status` show a 10-minute cert.
4. Use the access: `tsh kube login oss500 && kubectl get pods -n oss500-apps` (scoped to `env: oss500`, `oss500-apps` only). Try a resource outside the role's labels/namespace and watch it be denied — the role scopes by label, not a host list.
5. Let a short cert expire (or `tsh logout`) and re-run `kubectl get pods` through the Teleport kubeconfig → it fails. Access ended by **expiry**, exactly as a PIM activation window closes automatically.

### Part B — Session recording & audit (`pam-session`)

6. Confirm recording mode: `kubectl -n oss500-identity exec deploy/teleport -- tctl get cluster_networking_config` and check the auth config shows `session_recording: proxy-sync` — the proxy records the session as it passes through, so the evidence lives **off** the administered host.
7. Start a recorded interactive session: `tsh kube exec -it <pod> -n oss500-apps -- /bin/sh` (or `tsh ssh` if you enrolled an SSH node). Run a few commands, then exit.
8. List recorded sessions: `kubectl -n oss500-identity exec deploy/teleport -- tctl sessions ls` (or the Web UI → *Session Recordings*). Note the session ID.
9. Replay it byte-for-byte: `tsh play <session-id>`. You are watching the exact terminal stream of a privileged session — the "who did what during their elevated window" evidence access reviews and IR depend on.
10. Distinguish the two audit surfaces: the **structured audit log** (`tctl sessions ls`, and events like `cert.create`, `session.start`, `access_request.create`) is the who/what/when you'd ship to a SIEM (Wazuh/OpenSearch in Domain 4); the **session recording** is the replayable stream. They are different objects with different jobs.

### Part C — Access Requests / approval workflow (`pam-approval`) — WALKTHROUGH

*Full role-escalation flow needs two subjects (a requester and a distinct reviewer); documented here at exam depth and marked `walkthrough` in the tracker. You can drive it single-host by creating a second user.*

11. Baseline is *eligible, not active*: `alice` holds the `requester` role, which lists `request.roles: ['db-admin']` but grants **none** of db-admin's permissions. Prove it: `tsh kube login oss500` then attempt a `db-admin`-only action → denied.
12. Request elevation: `tsh request create --roles=db-admin --reason="INC-1234 hotfix"`. The request is **PENDING**; `alice` still has nothing.
13. Create a distinct reviewer and approve as them (separation of duties — the requester can't approve their own request): create user `bob` with the `reviewer` role, then `tctl request approve <request-id>` (or `tctl request deny <request-id> --reason=...`).
14. On approval, Teleport **re-issues alice's certificate with `db-admin` for a bounded window** (`max_session_ttl: 1h`). Re-run the privileged action → now allowed. When the window expires, it drops back to baseline.
15. Confirm the separation of duties in the roles: `requester` has `allow.request.roles`, `reviewer` has `allow.review_requests.roles` — two different subjects, no self-approval. Raise `thresholds.approve` to `2` for a two-person rule.

## Verification

- **JIT:** `tsh status` shows a certificate with a short **"Valid until"** (≤ 1 h); after it expires, the same `kubectl` call through Teleport is denied — access ended by expiry, not manual cleanup.
- **Recording:** `tsh play <session-id>` replays a privileged session captured at the proxy (off-host); `tctl sessions ls` shows the structured audit event for it.
- **Approval:** an access request shows **PENDING**, and the `db-admin` role appears in `tsh status` only **after** a *different* user approves it — eligible→approve→time-boxed active.

## Teardown

- `cd lab-infra/pam && ./down.sh`

## What the exam asks

- **Short-lived certificate TTL = the JIT enforcement.** "Eliminate standing admin access / time-bound elevation" → certs that expire, not a manual revoke step. The security property assumes there's **no direct path around the proxy**.
- **Proxy-side recording is tamper-resistant** because the evidence lives off the administered host; node-side recording is cheaper but a compromised target can alter it.
- **Audit events ≠ session recording**: the structured log (→ SIEM, drives access reviews) is distinct from the replayable session stream.
- **Eligible ≠ active**: a requestable baseline role grants nothing until an approved request re-issues the cert with the elevated role — a PIM eligible assignment activated via approval, time-boxed and audited.
- **Separation of duties**: `request.roles` (can ask) and `review_requests.roles` (can approve) are distinct; self-approval breaks the control. Approval thresholds = the approver list / two-person rule.
