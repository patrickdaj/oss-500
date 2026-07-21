# pam — Teleport (privileged access management)

Environment for the Domain 1 privileged-access lab ([guide](../../labs/d1-privileged-access.md)). A single-node self-hosted **Teleport** cluster (auth + proxy) that fronts SSH/Kubernetes/DB access, issues **short-lived certificates** instead of standing credentials, **records** privileged sessions off-host, and gates elevation behind **access requests** — the open-source stand-in for Azure PIM.

**Objectives:** `pam-jit`, `pam-session`, `pam-approval`
**Footprint:** ~1 GB · up ~3–5 min (image pull + first-boot CA generation)

Deploys the `teleport/teleport-cluster` chart into `oss500-identity` with `session_recording: proxy-sync` (`pam-session`), plus lab roles in [`roles.yaml`](roles.yaml): `db-oncall` with `max_session_ttl: 1h` (`pam-jit`) and a `requester`/`reviewer`/`db-admin` set for the approval flow (`pam-approval`). Security-relevant settings are commented against their objective in [`values.yaml`](values.yaml).

```bash
cp teleport-bootstrap.env.example teleport-bootstrap.env   # local only, gitignored
./up.sh                                                    # helm install + wait + bootstrap hints
# create roles + first user (commands printed by up.sh), then:
tsh login --insecure --proxy=localhost:3080 --user=alice
```

**Verify**
```bash
tsh status                                                 # short-lived cert, valid ~1h (pam-jit)
kubectl -n oss500-identity exec deploy/teleport -- tctl get roles | grep -A2 db-oncall   # max_session_ttl: 1h
tsh play <session-id>                                      # replay a recorded privileged session (pam-session)
tsh request create --roles=db-admin --reason="INC-1234"    # PENDING until a reviewer approves (pam-approval)
```

**Teardown:** `./down.sh` (removes the release, PVCs, generated secrets, and recordings). Confirm with `kubectl get all -n oss500-identity -l app.kubernetes.io/part-of=oss500`.
