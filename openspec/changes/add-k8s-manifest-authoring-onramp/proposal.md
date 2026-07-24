## Why

Phase 0 is entirely imperative: `02-kubernetes.md` teaches the learner to *run* pods with `kubectl create`/`kubectl run`, and they exit Phase 0 never having written a pod spec. Yet the Phase-0 self-check's first item and Phase 1 Days 3/5 demand exactly that — authoring `securityContext`, probes, and resource limits in YAML (audit P5 / Part 5.1). For the persona this is the single biggest authoring gap: he can operate a cluster but has never declared a hardened workload declaratively, which is the substrate every admission/pod-security lab assumes.

A second, adjacent Phase-0 gap rides along: the plan's Day-4 1.5h "RBAC preview" block has no backing content — it points only at the full Phase-1 RBAC deep-dive, a note the learner reaches weeks later (audit Part 5.3). The preview block currently has nothing to read.

## What Changes

- Add a **first annotated manifest** to `02-kubernetes.md`: one complete hardened pod YAML — `runAsNonRoot`, `runAsUser`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, resource `limits`, and a probe — applied with `kubectl apply` and verified by a write-denied check (a write to the read-only root filesystem fails).
- Add a read-what-you-ran step: `kubectl get deploy nginx -o yaml` to show the learner the full spec the imperative command generated, bridging "run" to "author."
- Add a short **"RBAC in 10 minutes"** section to `02-kubernetes.md` — Roles/ClusterRoles, RoleBindings/ClusterRoleBindings, subjects (ServiceAccount/user), and verb/resource rules, with a `kubectl auth can-i` check — so the Day-4 RBAC-preview block has backing content instead of forward-referencing the Phase-1 deep-dive.
- No new tracked objective and no `tracker.yaml` change (Domain 0 fundamentals are untracked reading); external links satisfy the `resource-citation` standard.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `oss-curriculum`: adds a requirement that the Phase-0 Kubernetes fundamentals note teach *authoring* a hardened pod manifest (not only imperative `kubectl` usage), so the learner has written a `securityContext`/probe/limits spec before the admission and pod-security labs demand it; and a requirement that the note carry a short "RBAC in 10 minutes" preview backing the Day-4 RBAC block.

## Impact

- Affected specs: `oss-curriculum` (two ADDED requirements).
- Affected content (at implementation time): `domains/0-fundamentals/02-kubernetes.md` (a hardened-pod authoring section + a `-o yaml` read step + an "RBAC in 10 minutes" section).
- Backs the Phase-0 self-check first item (P5), Phase 1 Days 3/5, and the Day-4 RBAC-preview block (Part 5.3).
