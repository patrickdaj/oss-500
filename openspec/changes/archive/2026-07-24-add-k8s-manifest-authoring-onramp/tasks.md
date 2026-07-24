## 1. Author the hardened-manifest section

- [x] 1.1 In `domains/0-fundamentals/02-kubernetes.md`, add one complete hardened pod YAML: `runAsNonRoot`, `runAsUser`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, resource `limits`, and a probe.
- [x] 1.2 Add `kubectl apply -f` for the manifest plus a write-denied verification step (a write to the read-only root filesystem fails), so the learner sees the hardening enforced.
- [x] 1.3 Add a `kubectl get deploy nginx -o yaml` step that shows the full spec an imperative command generated, bridging run→author.
- [x] 1.4 Ensure new external links satisfy `resource-citation` and `npm run lint:links` passes; confirm no `tracker.yaml`/objective change.

## 2. Add the RBAC-in-10-minutes preview

- [x] 2.1 In `domains/0-fundamentals/02-kubernetes.md`, add a short "RBAC in 10 minutes" section: Roles/ClusterRoles, RoleBindings/ClusterRoleBindings, subjects (ServiceAccount/user), verb/resource rules, and a `kubectl auth can-i` check.
- [x] 2.2 Scope it as a 10-minute orientation and cross-link the canonical Phase-1 RBAC deep-dive for depth (no duplication of the full objective).
- [x] 2.3 Confirm the plan's Day-4 RBAC-preview block can point at this section instead of only forward-referencing Phase 1.

## 3. Validation

- [x] 3.1 Run `openspec validate add-k8s-manifest-authoring-onramp --type change --strict` and confirm it passes.
