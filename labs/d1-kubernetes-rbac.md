# Lab d1: Kubernetes RBAC

Prove least privilege the way the exam frames it — a subject that provably *can't* do what it wasn't granted, and an audit that finds the over-permissioned ones.

**Objectives covered**

| id | Objective |
|---|---|
| `rbac-roles` | Create Roles/ClusterRoles and bindings scoped to subjects and namespaces |
| `rbac-least` | Apply least-privilege and separate duties across subjects |
| `rbac-audit` | Audit RBAC to find over-permissioned subjects and risky bindings |

**SC-500 correspondence**: Azure RBAC (role definitions + assignments at scope); least-privilege / RBAC; access reviews / entitlement management.

**Prerequisites**
- Base kind cluster up: `kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml && lab-infra/shared/up.sh` (no dedicated `lab-infra/` component — RBAC ships with Kubernetes).
- Audit tooling (via [krew](https://krew.sigs.k8s.io/) (reference)): `kubectl krew install who-can` and [`rbac-tool`](https://github.com/alcideio/rbac-tool) (`kubectl krew install rbac-tool` or the standalone binary).
- Notes read: [kubernetes-rbac.md](../domains/1-identity-governance/kubernetes-rbac.md).

**Estimated time**: 2 h · $0 (local)

## Steps

### Part A — Roles, ClusterRoles & bindings (`rbac-roles`)

1. Create a subject to reason about — a ServiceAccount in `oss500-apps`:
   ```bash
   kubectl -n oss500-apps create serviceaccount reports
   ```
2. Create a **namespaced** read-only Role and bind it to that SA:
   ```bash
   kubectl apply -f - <<'EOF'
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata: { name: pod-reader, namespace: oss500-apps }
   rules:
     - apiGroups: [""]              # "" = the core API group (common gotcha)
       resources: ["pods", "pods/log"]
       verbs: ["get", "list", "watch"]   # rbac-roles: read-only — no create/delete/exec
   ---
   apiVersion: rbac.authorization.k8s.io/v1
   kind: RoleBinding
   metadata: { name: reports-pod-reader, namespace: oss500-apps }
   subjects:
     - kind: ServiceAccount
       name: reports
       namespace: oss500-apps
   roleRef: { kind: Role, name: pod-reader, apiGroup: rbac.authorization.k8s.io }
   EOF
   ```
3. **Prove the binding sets the scope.** The built-in `view` ClusterRole bound with a *RoleBinding* is namespace-limited; bound with a *ClusterRoleBinding* it is cluster-wide. Demonstrate both, then delete the cluster-wide one:
   ```bash
   # namespace-scoped: view only in oss500-apps
   kubectl -n oss500-apps create rolebinding reports-view --clusterrole=view --serviceaccount=oss500-apps:reports
   kubectl auth can-i list deployments -n oss500-apps --as=system:serviceaccount:oss500-apps:reports   # yes
   kubectl auth can-i list deployments -n kube-system  --as=system:serviceaccount:oss500-apps:reports   # no

   # cluster-wide: the SAME ClusterRole, but now everywhere — the classic over-scope bug
   kubectl create clusterrolebinding reports-view-all --clusterrole=view --serviceaccount=oss500-apps:reports
   kubectl auth can-i list deployments -n kube-system  --as=system:serviceaccount:oss500-apps:reports   # now yes!
   kubectl delete clusterrolebinding reports-view-all      # undo the over-scope
   ```

### Part B — Least privilege & separation of duties (`rbac-least`)

4. Confirm the SA is read-only — it must **not** be able to write:
   ```bash
   kubectl auth can-i create deployments -n oss500-apps --as=system:serviceaccount:oss500-apps:reports   # no
   kubectl auth can-i delete pods        -n oss500-apps --as=system:serviceaccount:oss500-apps:reports   # no
   ```
5. **Escalation verbs.** Show that `escalate`/`bind`/`impersonate` and `create pods` are privilege-escalation primitives, not routine grants. Create a "deployer" role that deliberately *omits* them, and a "security-admin" role that *has* RBAC verbs — that split is the separation of duties:
   ```bash
   # deployer: manage workloads, but NOT RBAC and NOT impersonation
   kubectl -n oss500-apps create role deployer \
     --verb=get,list,watch,create,update,patch,delete \
     --resource=deployments,replicasets,pods
   # A deployer must NOT be able to grant itself more:
   kubectl auth can-i create rolebindings -n oss500-apps --as=system:serviceaccount:oss500-apps:reports   # no
   kubectl auth can-i impersonate users   --as=system:serviceaccount:oss500-apps:reports                  # no
   ```
   Note the trap: a subject with `create pods` in a namespace can schedule a pod under *any* ServiceAccount there and inherit its token — so never leave a highly privileged SA in a namespace where many subjects can create pods.
6. **The `default` SA gets nothing.** Verify no RoleBinding targets it (`kubectl get rolebindings -n oss500-apps -o wide`); binding roles to `default` silently over-privileges every pod that omits `serviceAccountName`.

### Part C — Audit over-permissioned subjects (`rbac-audit`)

7. Plant a deliberately risky binding so the audit has something to find:
   ```bash
   kubectl create clusterrolebinding oops-admin --clusterrole=cluster-admin --serviceaccount=oss500-apps:reports
   ```
8. **Forward question** — *who can do this sensitive action?* (access-review framing):
   ```bash
   kubectl who-can list secrets -A         # names every subject that can read secrets
   kubectl who-can '*' '*'                 # who is effectively cluster-admin — reports should appear now
   ```
9. **Reverse question** — *what can this subject do?* Effective permission is the union of all bound roles:
   ```bash
   rbac-tool policy-rules -e '^system:serviceaccount:oss500-apps:reports$'
   kubectl auth can-i --list --as=system:serviceaccount:oss500-apps:reports -n oss500-apps
   ```
10. **Lint the whole cluster** — `rbac-tool analysis` flags wildcards, cluster-admin bindings, escalation verbs, and `default`-SA grants; `rbac-tool viz` renders the subject→role→resource graph:
    ```bash
    rbac-tool analysis        # should flag the oops-admin ClusterRoleBinding
    rbac-tool viz --outformat html --outfile /tmp/rbac.html
    ```
11. Remediate — remove the risky binding and re-audit to confirm it's gone:
    ```bash
    kubectl delete clusterrolebinding oops-admin
    kubectl who-can '*' '*'    # reports no longer listed
    ```

## Verification

- `kubectl auth can-i create deployments --as=system:serviceaccount:oss500-apps:reports -n oss500-apps` returns **no**, while `kubectl auth can-i list pods ...` returns **yes** — least privilege provably holds.
- `kubectl who-can list secrets -A` names *exactly* the intended subjects (not the `reports` SA).
- `rbac-tool analysis` flags the deliberately over-broad `oops-admin` ClusterRoleBinding; after `kubectl delete clusterrolebinding oops-admin`, `kubectl who-can '*' '*'` no longer lists `reports`.

## Teardown

- `kubectl -n oss500-apps delete rolebinding reports-pod-reader reports-view; kubectl -n oss500-apps delete role pod-reader deployer; kubectl -n oss500-apps delete serviceaccount reports; kubectl delete clusterrolebinding oops-admin --ignore-not-found` (base cluster stays up for the next lab).

## What the exam asks

- **The binding sets the scope**: a ClusterRole bound by a RoleBinding is namespace-limited; by a ClusterRoleBinding it is cluster-wide — the "why can this SA read every namespace's secrets" bug. Same as choosing an Azure role-assignment scope.
- **RBAC is additive with no deny rule** — you restrict by *not granting*, never by subtracting; answers proposing a "deny rule" are wrong (Azure deny assignments have no Kubernetes equivalent).
- **Escalation verbs** `escalate`, `bind`, `impersonate` (and `create pods` → assume any SA) let a subject exceed its nominal permissions — the usual root cause of "user has only role X but became admin."
- **Two audit directions**: *who-can* (forward — who can do this) for access reviews; *policy-rules / `can-i --list`* (reverse — what can this subject do). Effective permission is the union of all bound roles.
- **Auditing is detective, not preventive** — it *finds* the over-permission; to stop it recurring you enforce at admission with Kyverno/Gatekeeper (`d1-governance`).
