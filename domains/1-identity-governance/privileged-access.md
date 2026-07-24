# Implement privileged access management (PIM equivalent)

Domain 1, subsection 3 (`d1-pam`). Privileged access management is the discipline of granting elevated access *only when needed, only for a while, and always on the record*. Azure does this with **Privileged Identity Management (PIM)**: eligible-not-active assignments, activation with approval, and full audit. The open-source equivalent is an **identity-aware access proxy** — **Teleport** (or HashiCorp **Boundary**) — that fronts SSH, Kubernetes, and databases, issues **short-lived certificates** instead of standing credentials, **records** every privileged session, and gates elevation behind **access requests** with reviewers. Primary lab: [d1-privileged-access](../../labs/d1-privileged-access.md); lab-infra component: [`lab-infra/pam`](../../lab-infra/pam/) (Teleport on the kind cluster).

## Implement just-in-time privileged access with short-lived credentials

*Objective: `pam-jit` · OSS: Teleport / Boundary ≈ SC-500: Privileged Identity Management (PIM) · Lab: [d1-privileged-access](../../labs/d1-privileged-access.md)*

The core PIM idea is that privilege should be **time-bound and revocable by expiry, not by remembering to remove it**. Teleport implements this with **certificate-based, short-lived access**: a user runs `tsh login`, authenticates (ideally via SSO/MFA), and receives an **X.509 and SSH certificate with a TTL** (default 12 h, tunable down to minutes). No static SSH keys, no standing database passwords, no long-lived kubeconfig — when the certificate expires, access is simply gone, the same "activation window closes automatically" property PIM gives an activated role. Roles cap this with `max_session_ttl`, and a **Teleport role** binds *who* to *what*: allowed logins, which clusters/nodes/databases (by label), and the certificate TTL.

```yaml
kind: role
version: v7
metadata: { name: db-oncall }
spec:
  options:
    max_session_ttl: 1h        # pam-jit: certificates expire in 1h — no standing access
  allow:
    logins: ['readonly']
    kubernetes_labels: { 'env': 'oss500' }   # scoped to labelled resources only
    db_labels: { 'tier': 'app' }
```

Because Teleport is an **identity-aware proxy**, every connection is authenticated and authorized centrally — there is no direct network path to the protected host that bypasses it. That closes the standing-bastion / shared-jump-host gap: instead of a permanent admin key on a bastion, each session is a freshly minted, expiring credential tied to an identity. Boundary reaches the same outcome differently — brokered, time-boxed **sessions** with credentials injected from a secrets store rather than long-lived certs — but the exam concept is identical: *just-in-time, short-lived, no standing privilege*.

Mechanically, `tsh login` performs SSO (Teleport can broker to Keycloak/Entra/GitHub as the identity source — the `d1-idp` tie-in) and MFA, then the **Teleport Auth Service** signs a certificate whose extensions encode the user's **roles and traits**; every subsequent SSH/kube/db connection is authorized by re-evaluating those roles at the proxy. Because the credential is a short-TTL cert rather than a revocable session, immediate cutoff needs a **lock** (`tctl lock --user=alice` / `--role=db-admin`) — the Auth Service rejects locked identities in real time, the answer to "a cert is still valid but I must revoke access *now*." Additional standing-access controls layer on top: **`require_session_mfa`** (MFA per connection, not just at login) and **device trust** (only enrolled devices may connect) — the Teleport shape of Entra Conditional Access requiring MFA and a compliant device for privileged action.

Exam gotchas:

- **Short-lived certificate TTL is the JIT enforcement** — access ends when the cert expires, not when someone revokes it. Map "eliminate standing admin access / time-bound elevation" to this, exactly as PIM activation is time-boxed.
- **No direct path around the proxy**: the security property depends on the protected resources only being reachable *through* Teleport/Boundary. A leftover direct SSH route defeats it — the analogue of a resource still reachable outside PIM's control.
- Teleport = **short-lived certificates**; Boundary = **brokered sessions with injected credentials**. Both are JIT; don't assume "PAM" means only one mechanism.
- Roles scope by **label**, not hostname lists — over-broad label selectors (`'*': '*'`) are the over-privilege finding, the PIM parallel to an eligible assignment scoped too widely.
- **Short TTL ≠ instant revocation.** Because access ends by *expiry*, an already-issued cert stays valid for its window; to kill a session or identity immediately you need a **lock** (`tctl lock`), not a role edit. "Contain a compromised admin right now" → lock, not TTL.
- **A shorter `max_session_ttl` trades convenience for exposure** but doesn't replace MFA/least-privilege; a 12h cert with `cluster-admin`-equivalent labels is still standing-ish over-privilege. TTL bounds *duration*, roles bound *scope* — the exam tests both.

**Resources:**
- [Teleport — Access Controls and roles](https://goteleport.com/docs/admin-guides/access-controls/guides/role-templates/) `[depth]` (~20 min)
- [Teleport — Architecture and certificate-based access](https://goteleport.com/docs/reference/architecture/) `[depth]` (~20 min)
- [Teleport — Core concepts (auth/proxy, roles, certs)](https://goteleport.com/docs/core-concepts/) `[depth]` (~15 min)
- [HashiCorp Boundary — Credential management: Credential brokering (brokered JIT sessions)](https://developer.hashicorp.com/boundary/docs/concepts/credential-management#credential-brokering) `[depth]` (~20 min)
- [Microsoft Learn — Configure Privileged Identity Management (PIM)](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-configure) `[depth]` (~20 min)

## Configure session recording and audit for privileged sessions

*Objective: `pam-session` · OSS: Teleport session recording ≈ SC-500: PIM audit / access reviews · Lab: [d1-privileged-access](../../labs/d1-privileged-access.md)*

PIM isn't only about *granting* elevation — it's about *proving what was done with it*. Teleport records privileged activity at two levels: a **structured audit log** of every event (login, session start/end, access request, cert issuance) as discrete JSON records, and **full session recordings** — the complete interactive terminal (and Kubernetes `exec`) stream, replayable byte-for-byte with `tsh play <session-id>`. This is the open-source equivalent of PIM's audit history plus the "who did what during their activated window" evidence trail that access reviews and incident response depend on.

Recording location is a deliberate security choice set by `session_recording`:

- **`node` / `node-sync`** — the agent on the target records. Lower proxy load, but a compromised node could tamper with its own recording.
- **`proxy` / `proxy-sync`** — the Teleport **proxy** records the session as it passes through, so the recording lives *outside* the host being administered — tamper-resistant even if the target is compromised. The `-sync` variants stream directly to storage (S3/filesystem) with no local buffer, closing the "delete the local recording before it uploads" gap.

**Enhanced session recording** (eBPF/BPF) additionally captures the commands, network connections, and file activity *inside* a session — catching actions a raw terminal replay would miss (e.g. a script's syscalls). Recordings and audit events export to a SIEM (Wazuh/OpenSearch in Domain 4) for correlation and long-term retention.

```yaml
# teleport auth_service config
auth_service:
  session_recording: proxy-sync   # pam-session: record at the proxy, off the target host; stream to storage
  audit_events_uri: ['stdout://']
  audit_sessions_uri: 's3://oss500-teleport-sessions'
```

Exam gotchas:

- **Proxy-side recording is tamper-resistant** because the evidence lives off the administered host; `node` recording is cheaper but a compromised target can alter it. "Ensure privileged-session evidence survives host compromise" → proxy-sync.
- **Audit events ≠ session recording**: the audit log is the structured who/what/when (feed a SIEM, drive access reviews); the recording is the replayable session. The exam distinguishes "log of the activation" from "replay of the session."
- **Enhanced (BPF) recording** captures in-session commands/network/files beyond the terminal stream — the answer to "detect what a script actually did," not plain terminal replay.
- Recording is what turns JIT access into **auditable** JIT access — the PIM value isn't just short-lived, it's short-lived *and reviewable*.
- **Recording can be bypassed if a resource is reachable off-proxy** (see `pam-jit`): a session that never traverses Teleport is never recorded. Auditability depends on the same "no path around the proxy" invariant as JIT.
- **Retention and export are the compliance half**: recordings/events must land in durable, access-controlled storage (S3 with object-lock, or a SIEM) to survive an attacker with host access and to satisfy log-retention requirements — the reason `-sync` streaming and off-cluster storage matter.

**Resources:**
- [Teleport — Session recording architecture](https://goteleport.com/docs/reference/architecture/session-recording/) `[depth]` (~15 min)
- [Teleport — Audit log and events](https://goteleport.com/docs/reference/monitoring/audit/) `[depth]` (~15 min)
- [Teleport — Enhanced session recording for SSH with BPF](https://goteleport.com/docs/enroll-resources/server-access/guides/bpf-session-recording/) `[depth]` (~20 min)
- [NIST SP 800-92 — Guide to Computer Security Log Management](https://csrc.nist.gov/pubs/sp/800/92/final) `[depth]` (~30 min)
- [Microsoft Learn — View audit history for roles in PIM](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-how-to-use-audit-log) `[depth]` (~15 min)

## Require approval workflows and role escalation for privileged roles

*Objective: `pam-approval` · OSS: Teleport access requests ≈ SC-500: PIM approval / eligible assignments · Lab: [d1-privileged-access](../../labs/d1-privileged-access.md) (walkthrough)*

The signature PIM workflow is **eligible → request → approve → time-boxed activate**. Teleport implements it with **Access Requests**: a user holds a baseline role that is *eligible* to request elevation but carries none of the elevated permissions by default, then runs `tsh request create --roles=db-admin --reason="INC-1234"`. That request is **pending** until a **reviewer** with the right to approve acts on it; on approval the user's certificate is re-issued *with the elevated role for a bounded window*, and on expiry it drops back. This is a near-exact analogue of a PIM **eligible assignment** activated through an **approval** — nobody carries `db-admin` standing; they borrow it, with justification, for a while, on the record.

```bash
# Requester (holds only the eligible baseline role)
tsh request create --roles=db-admin --reason="INC-1234 hotfix"

# Reviewer approves/denies — the escalation event is audited
tctl request approve <request-id>
tctl request deny    <request-id> --reason="use read-only role"
```

Policy is expressed in roles: an `allow.request.roles` list makes a role *requestable* (eligibility), while `spec.allow.review_requests.roles` grants *review* authority — a clean **separation of duties** (requesters can't approve their own escalations). You can require a **threshold** of approvals, set per-role reasons as mandatory, auto-expire pending requests, and wire notifications/approvals to Slack, PagerDuty, Jira, or Microsoft Teams for out-of-band sign-off — the same "route to an approver" step PIM performs. Every request, approval, denial, and the resulting elevated session lands in the audit log, giving access reviews a complete elevation history.

Exam gotchas:

- **Baseline role = eligible, not active**: holding a requestable role grants *nothing* until an approved request re-issues the certificate — precisely a PIM eligible assignment that grants no permission until activation.
- **Separation of duties**: `request.roles` (can ask) and `review_requests.roles` (can approve) are distinct; a design where a user can approve their own request breaks the control — the PIM parallel to self-approval.
- **Approval thresholds and mandatory reason/justification** map to PIM's approver list and justification requirements; multi-approver = the two-person rule.
- Elevation is **time-boxed and audited** — approval doesn't grant standing access, it grants a bounded, recorded window; "permanent admin after one approval" is wrong by design.
- **Break-glass still needs a path**: a role that can approve requests but is itself gated behind approval can deadlock in an incident. Keep an audited emergency account/role excluded from the approval requirement — the same break-glass exclusion as a blocking CA policy, and PIM's emergency-access accounts.
- **Requestable ≠ granted**: `allow.request.roles` only lets a subject *ask*; a reviewer with `review_requests.roles` must approve before the elevated cert is issued. A design that skips review (auto-approve) collapses the control back to standing access.

**Resources:**
- [Teleport — Access Requests (just-in-time approvals)](https://goteleport.com/docs/admin-guides/access-controls/access-requests/) `[depth]` (~25 min)
- [Teleport — Access Request plugins (Slack/PagerDuty/Jira)](https://goteleport.com/docs/admin-guides/access-controls/access-request-plugins/) `[depth]` (~15 min)
- [Microsoft Learn — Approve/deny requests for roles in PIM](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-resource-roles-approval-workflow) `[depth]` (~15 min)
- [NIST SP 800-207 — Zero Trust Architecture (JIT/least-privilege access)](https://csrc.nist.gov/pubs/sp/800/207/final) `[depth]` (~30 min)

## Summary

| Objective | Takeaway |
|---|---|
| `pam-jit` | Identity-aware proxy issues short-lived certs (TTL = the JIT window); no standing keys, no path around the proxy; Teleport certs vs Boundary brokered sessions |
| `pam-session` | Record at the proxy (tamper-resistant, off-host) vs node; audit events (structured, → SIEM) ≠ session recording (replayable); BPF enhanced recording catches in-session actions |
| `pam-approval` | Access Requests = eligible→request→approve→time-boxed activate; separate request vs review roles (SoD), thresholds, justification, out-of-band approval — PIM eligible + approval |
