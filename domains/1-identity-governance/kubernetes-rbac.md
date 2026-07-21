# Implement role-based access control on the cluster

Domain 1, subsection 4 (`d1-k8s-rbac`). Kubernetes RBAC is the cluster's authorization system — the open-source counterpart of **Azure RBAC**. Same building blocks: a *role* is a set of allowed actions, a *binding* attaches that role to *subjects* at a *scope*, and the model is **least-privilege by construction** because it is purely additive (there is no allow-by-default and no deny rule). The SC-500 skills — designing roles, scoping them, enforcing least privilege, and *reviewing* who has what — all have exact Kubernetes analogues you can test with `kubectl auth can-i`. Primary lab: [d1-kubernetes-rbac](../../labs/d1-kubernetes-rbac.md); it runs on the base kind cluster with `rbac-tool` and `kubectl-who-can`.

## Create Roles/ClusterRoles and bindings scoped to subjects and namespaces

*Objective: `rbac-roles` · OSS: Kubernetes RBAC ≈ SC-500: Azure RBAC · Lab: [d1-kubernetes-rbac](../../labs/d1-kubernetes-rbac.md)*

Kubernetes RBAC has four objects, and the whole model is understanding which scope each covers:

- **Role** — a namespaced set of permission **rules** (`apiGroups` × `resources` × `verbs`, optionally narrowed by `resourceNames`). Like an Azure role definition, but namespace-scoped.
- **ClusterRole** — the same rules at cluster scope; also reusable *inside* a namespace when referenced by a RoleBinding. Covers cluster-scoped resources (nodes, PVs) and non-resource URLs.
- **RoleBinding** — attaches a Role *or* a ClusterRole to **subjects** (`User`, `Group`, `ServiceAccount`) **within one namespace** — the scope of the grant is the binding's namespace.
- **ClusterRoleBinding** — attaches a ClusterRole to subjects **across the whole cluster**.

The scope of a permission is decided by the **binding**, not the role: bind a ClusterRole with a *RoleBinding* and it applies only in that namespace; bind it with a *ClusterRoleBinding* and it applies everywhere. That single distinction is the most tested idea here and the direct parallel of choosing an Azure role-assignment scope (resource group vs subscription).

```yaml
# A namespaced read-only role and its binding to a ServiceAccount subject
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { name: pod-reader, namespace: oss500-apps }
rules:
  - apiGroups: [""]           # "" = core group
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]   # rbac-roles: read-only, no create/delete/exec
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: reports-pod-reader, namespace: oss500-apps }
subjects:
  - kind: ServiceAccount
    name: reports
    namespace: oss500-apps
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

Kubernetes ships default ClusterRoles you should recognize and reach for before writing your own: **`view`** (read-only, no secrets), **`edit`** (read/write workloads, no RBAC), **`admin`** (full namespace admin via RoleBinding), and **`cluster-admin`** (everything — the `system:masters` superuser). Because RBAC is **purely additive with no deny**, a subject's effective permission is the union of every rule from every role bound to it; you restrict by *not granting*, never by subtracting.

Two structural details the exam likes. First, RBAC is only **one authorizer in a chain** (Node, RBAC, Webhook, …) evaluated by the API server; a request is allowed if *any* authorizer allows it, so `system:masters` (hard-coded, ignores RBAC) and Node authorization exist alongside your RBAC. Second, ClusterRoles can be **aggregated**: an `aggregationRule` with a label selector unions in every ClusterRole carrying the matching label — which is how the built-in `view`/`edit`/`admin` roles automatically pick up permissions for new CRDs, and a subtle over-grant vector if you label a powerful custom ClusterRole into `edit`. Subjects are `User`/`Group` (opaque strings the authenticator asserts — there is no `User` object in Kubernetes) and `ServiceAccount` (a real object); groups like `system:authenticated` and `system:serviceaccounts` are implicit and dangerous to bind.

Exam gotchas:

- **The binding sets the scope.** A ClusterRole bound by a RoleBinding is namespace-limited; the same ClusterRole bound by a ClusterRoleBinding is cluster-wide — the classic "why can this SA read secrets in *every* namespace" bug is a ClusterRoleBinding where a RoleBinding was intended.
- **RBAC is additive, no deny rules.** Unlike Azure deny assignments, Kubernetes has no way to subtract a permission — you achieve restriction by scoping the grant. Answers proposing a "deny rule" are wrong.
- **Prefer the built-in `view`/`edit`/`admin` ClusterRoles**; `cluster-admin` / `system:masters` is the break-glass superuser and almost never the right answer for a specific need.
- `verbs`, `resources`, and `apiGroups` are all required and case-sensitive; the core API group is the **empty string `""`**, a frequent gotcha in hand-written rules.
- **`roleRef` is immutable**: you cannot re-point an existing binding at a different role — you must delete and recreate it. A "changed the role but the binding still grants the old one" symptom is usually an un-recreated binding.
- **RBAC authorizes API verbs, not arbitrary actions**: some powers (e.g. `exec`/`attach`/`port-forward`) map to subresources (`pods/exec`) you must name explicitly; granting `pods` alone does *not* grant `pods/exec`.

**Resources:**
- [Kubernetes — Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) (~30 min)
- [Kubernetes — Default roles and role bindings](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#default-roles-and-role-bindings) (~15 min)
- [Kubernetes — Authorization overview (the authorizer chain, `can-i`)](https://kubernetes.io/docs/reference/access-authn-authz/authorization/) (~15 min)
- [CIS Kubernetes Benchmark (RBAC & access-control controls)](https://www.cisecurity.org/benchmark/kubernetes) (~20 min)
- [Microsoft Learn — Azure RBAC overview (the SC-500 mapping)](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview) (~15 min)

## Apply least-privilege and separate duties across subjects

*Objective: `rbac-least` · OSS: Kubernetes RBAC ≈ SC-500: Least-privilege / RBAC · Lab: [d1-kubernetes-rbac](../../labs/d1-kubernetes-rbac.md)*

Least privilege in Kubernetes means **narrow verbs, narrow resources, narrow scope, and narrow subjects** — the same discipline as a tightly scoped Azure custom role at the smallest necessary scope. Concretely: avoid wildcards (`verbs: ["*"]`, `resources: ["*"]`, `apiGroups: ["*"]`), grant `get/list/watch` when the job is reading and never `create/delete`, use `resourceNames` to pin a rule to a single object, and bind at the **namespace** with a RoleBinding rather than the cluster whenever possible. Separation of duties falls out of splitting roles: a "deployer" gets `edit` on workloads but *not* RBAC verbs, while a "security admin" manages RBAC but doesn't run workloads.

Some verbs and resources are **privilege-escalation primitives** and are where least-privilege really bites:

- **`escalate` / `bind`** on roles/clusterroles — lets a subject grant itself (or others) permissions it doesn't already hold. A subject with `bind` can attach `cluster-admin` to itself. Guard these tightly.
- **`impersonate`** on users/groups/serviceaccounts — lets a subject act *as* anyone, sidestepping their own limits (`kubectl --as=...`). Effectively a master key.
- **`create` on pods (or deployments)** — a pod can be scheduled with *any* ServiceAccount in the namespace and mount its token, so "create pods" implicitly grants that SA's powers. Pair with a highly privileged SA in the namespace and it's an escalation path.
- **`get/list` on secrets** — reading secrets is reading credentials; treat it as sensitive, not routine.

```bash
# Prove least privilege the way the exam frames it — test, don't assume:
kubectl auth can-i create deployments -n oss500-apps --as=system:serviceaccount:oss500-apps:reports   # expect: no
kubectl auth can-i get secrets       -n oss500-apps --as=system:serviceaccount:oss500-apps:reports   # expect: no
kubectl auth can-i list pods         -n oss500-apps --as=system:serviceaccount:oss500-apps:reports   # expect: yes
```

The **`default` ServiceAccount** deserves special care: it exists in every namespace, workloads use it if none is specified, and it should hold *no* RoleBindings — granting it permissions silently over-privileges every default pod, the Kubernetes echo of an over-broad Azure built-in role left on a principal.

Exam gotchas:

- **`escalate`, `bind`, `impersonate` are escalation verbs** — a subject with them can exceed its nominal permissions. "User has only role X but can become admin" usually traces to one of these (or to `create pods` + a privileged SA).
- **`create pods`/`create deployments` ⇒ access to any SA in the namespace** (the pod can run as it). Keep privileged ServiceAccounts out of namespaces where lots of subjects can create pods.
- **Never bind roles to the `default` SA** and never grant `system:authenticated`/`system:unauthenticated` broad rights — both silently widen access to everyone.
- Least privilege = **narrow role AND narrow scope AND narrow subject**; a `view` ClusterRole bound cluster-wide is still too broad if the job needed one namespace — the same "narrow the role and the scope" lesson as Azure RBAC.
- **Least privilege is layered, not just RBAC**: the `create pods`→SA-takeover path is only closed when **Pod Security admission** (or a policy engine) also restricts what those pods can do; RBAC alone can't stop a permitted pod from running privileged. Pair `d1-k8s-rbac` with `d1-governance`.

**Resources:**
- [Kubernetes — RBAC good practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/) (~20 min)
- [Kubernetes — Privilege escalation prevention (escalate/bind)](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#privilege-escalation-prevention-and-bootstrapping) (~10 min)
- [Kubernetes — Security checklist](https://kubernetes.io/docs/concepts/security/security-checklist/) (~15 min)
- [Kubernetes — Pod Security Standards (restricting what a pod can do)](https://kubernetes.io/docs/concepts/security/pod-security-standards/) (~15 min)
- [OWASP — Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html) (~20 min)

## Audit RBAC to find over-permissioned subjects and risky bindings

*Objective: `rbac-audit` · OSS: rbac-tool / kubectl-who-can ≈ SC-500: Access reviews / entitlement management · Lab: [d1-kubernetes-rbac](../../labs/d1-kubernetes-rbac.md)*

Granting least privilege once isn't enough — permissions drift, and someone has to periodically answer "**who can do X?**" and "**what can this subject do?**" That recertification is exactly what Azure **access reviews / entitlement management** provide, and on the cluster it's done with `kubectl auth can-i --list`, **`kubectl-who-can`**, and **`rbac-tool`**. Because RBAC is additive and spread across many Roles/ClusterRoles/bindings, effective permissions are non-obvious; these tools compute the union for you.

```bash
# Forward question: who can perform a sensitive action? (aquasecurity/kubectl-who-can)
kubectl who-can list secrets -n oss500-apps
kubectl who-can '*' '*'                       # who is effectively cluster-admin

# Reverse question: what can a subject do? and visualize/lint risky grants (alcideio/rbac-tool)
rbac-tool policy-rules -e '^system:serviceaccount:oss500-apps:reports$'
rbac-tool analysis                            # flags wildcards, cluster-admin bindings, escalation verbs
rbac-tool who-can list secrets
kubectl auth can-i --list --as=system:serviceaccount:oss500-apps:reports -n oss500-apps
```

The **risky patterns** an audit looks for are the access-review red flags: ClusterRoleBindings to `cluster-admin` (especially to groups or the `default` SA), wildcard `*` verbs/resources/apiGroups, the escalation verbs (`escalate`/`bind`/`impersonate`), broad `secrets` read, bindings to `system:authenticated`, and roles bound far more widely than their purpose. `rbac-tool analysis` scores these automatically; `rbac-tool viz` renders the subject→role→resource graph so an over-connected subject is visible at a glance. The remediation is the least-privilege one: replace the wildcard/cluster-wide grant with a narrow Role bound at the namespace, and remove bindings no longer justified — the cluster equivalent of an access review revoking stale entitlements.

Exam gotchas:

- **Two directions of audit**: *who-can* (forward — who can do this action) and *policy-rules/can-i --list* (reverse — what can this subject do). Access-review scenarios usually want the forward question ("who can read secrets").
- **Effective permission is the union of all bound roles** — you can't judge a subject from one binding. Tools exist precisely because additive RBAC hides the aggregate.
- **`rbac-tool analysis`/`viz`** surface the classic risks (wildcards, cluster-admin, escalation verbs, default-SA bindings) — the equivalent of an access-review report of over-privileged principals.
- Auditing is **detective**, not preventive: it finds the over-permission; enforcing it *stays* fixed is admission-time policy (Kyverno/Gatekeeper in `d1-governance`). Pair the two — find, then prevent recurrence.
- **`kubectl auth can-i --list` is built in and needs no extra tooling** — it answers the reverse question for the *current* (or `--as`-impersonated) subject and is the fastest exam-legal way to enumerate effective permissions; `--as`/`--as-group` requires `impersonate` rights, itself an escalation verb.
- **Audit must include ServiceAccounts, not just humans**: most over-privilege in a cluster is a workload SA with a stale ClusterRoleBinding, the direct analogue of an orphaned service-principal role assignment an access review should catch.

**Resources:**
- [rbac-tool (alcideio) — analysis, who-can, viz](https://github.com/alcideio/rbac-tool) (~15 min)
- [kubectl-who-can (Aqua Security)](https://github.com/aquasecurity/kubectl-who-can) (~10 min)
- [KubiScan (CyberArk) — find risky roles/bindings & escalation paths](https://github.com/cyberark/KubiScan) (~15 min)
- [Kubernetes — Checking API access (`kubectl auth can-i`)](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#checking-api-access) (~10 min)
- [Microsoft Learn — Access reviews (the SC-500 recertification control)](https://learn.microsoft.com/en-us/entra/id-governance/access-reviews-overview) (~15 min)

## Summary

| Objective | Takeaway |
|---|---|
| `rbac-roles` | Role/ClusterRole + RoleBinding/ClusterRoleBinding; the *binding* sets the scope; RBAC is additive with no deny; prefer built-in view/edit/admin over cluster-admin |
| `rbac-least` | Narrow verbs/resources/scope/subjects; watch escalation verbs (escalate/bind/impersonate) and `create pods`→SA takeover; never bind roles to the `default` SA; test with `auth can-i` |
| `rbac-audit` | who-can (forward) vs policy-rules/`can-i --list` (reverse); effective perms are the union; rbac-tool analysis/viz flag wildcards, cluster-admin, escalation verbs — access-review analogue |
