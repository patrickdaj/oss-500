# Harden pods and enforce workload security standards

Domain 3, subsection 1 (`d3-podsecurity`). Every workload on the cluster is a pod, and a pod's default posture — root user, writable root filesystem, all Linux capabilities, host namespaces available for the asking — is dangerously permissive. This subsection is about pulling that default back to least privilege and then *enforcing* it so a hardened baseline can't be quietly bypassed. Three layers stack here: the pod's own `securityContext` (what the container is actually allowed to do), the built-in **Pod Security Admission** controller (a namespace-level guardrail keyed off the Pod Security Standards), and a general-purpose admission policy engine — **Kyverno** or **OPA Gatekeeper** — for the rules PSA can't express.

Primary lab: [d3-pod-security](../../labs/d3-pod-security.md). Lab-infra component: [`lab-infra/governance`](../../lab-infra/governance/) (Kyverno + Gatekeeper) plus the Pod Security labels already baked into [`shared/namespaces.yaml`](../../lab-infra/shared/namespaces.yaml). The SC-500 analog throughout is **Azure Policy for AKS** and the **AKS deployment safeguards / built-in security baselines**.

## Apply Pod Security Admission and the Pod Security Standards

*Objective: `pod-psa` · OSS: Pod Security Admission ≈ SC-500: Pod security / AKS baselines · Lab: [d3-pod-security](../../labs/d3-pod-security.md)*

The **Pod Security Standards** are three named profiles — `privileged` (no restrictions), `baseline` (blocks the well-known escapes: host namespaces, privileged containers, most `hostPath`, dangerous capabilities), and `restricted` (baseline plus hardening: run-as-non-root, drop ALL capabilities, seccomp `RuntimeDefault`, no privilege escalation). **Pod Security Admission (PSA)** is the built-in admission controller — GA since Kubernetes 1.25 — that enforces one of these profiles per namespace. You opt a namespace in with labels:

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted   # reject violating pods
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: restricted      # kubectl warning on violations
    pod-security.kubernetes.io/audit: restricted     # audit-log annotation
```

The three modes matter: **`enforce`** rejects the pod at admission, **`warn`** returns a client warning but admits it, **`audit`** writes an annotation to the audit log. A common rollout is `warn`+`audit` at `restricted` first to find what breaks, then flip `enforce`. Note the granularity gap: PSA enforces at the *namespace* level and can't make per-workload exceptions — if one Deployment in a `restricted` namespace legitimately needs a capability, PSA can't grant just that; you either relax the whole namespace or move the workload. That limitation is exactly why Kyverno/Gatekeeper (`pod-admission`) exists alongside PSA.

In OSS-500 the standards are already wired in [`shared/namespaces.yaml`](../../lab-infra/shared/namespaces.yaml): `oss500-apps` and `oss500-identity` enforce `restricted`, `oss500-secrets` and `oss500-monitoring` enforce `baseline`, and `oss500-security` is deliberately `privileged` because Falco, Tetragon and friends need host mounts and eBPF — the documented exception. On SC-500, this maps to **AKS built-in policy initiatives** ("Kubernetes cluster pods should only use allowed security capabilities", the *baseline*/*restricted* Azure Policy sets) delivered via **Azure Policy for AKS**, which is itself Gatekeeper under the hood.

Exam gotchas:
- PSA has three *modes* (enforce/warn/audit) and three *profiles* (privileged/baseline/restricted). Don't conflate them — you can run `warn:restricted` while `enforce:baseline`.
- PSA is namespace-scoped and label-driven; it can't do per-pod exemptions or mutate resources. That's the boundary where you reach for an admission engine.
- The `privileged` profile is the *absence* of a control, not a control. A namespace with no PSA labels is effectively `privileged`.

**Resources:**
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) (~20 min)
- [Enforce Pod Security Standards with namespace labels](https://kubernetes.io/docs/tasks/configure-pod-security-admission/enforce-standards-namespace-labels/) (~15 min)

## Harden securityContext: non-root, read-only root FS, dropped capabilities, seccomp

*Objective: `pod-securitycontext` · OSS: Kubernetes securityContext ≈ SC-500: Container hardening · Lab: [d3-pod-security](../../labs/d3-pod-security.md)*

`securityContext` is where a workload actually declares its runtime privileges, at both the pod and container level. The `restricted` standard is really a checklist over these fields, and knowing them cold is the point of this objective. A hardened container:

```yaml
securityContext:
  runAsNonRoot: true          # kubelet refuses to start a container that would run as UID 0
  runAsUser: 10001
  allowPrivilegeEscalation: false   # blocks setuid/gaining caps beyond the parent (no_new_privs)
  readOnlyRootFilesystem: true      # root FS mounted RO; writes go to explicit emptyDir volumes
  capabilities:
    drop: ["ALL"]                   # start from zero Linux capabilities...
    add: ["NET_BIND_SERVICE"]       # ...add back only what's proven necessary
  seccompProfile:
    type: RuntimeDefault            # apply the container runtime's default syscall filter
```

Each field closes a specific escape. `runAsNonRoot`/`runAsUser` mean a container breakout lands as an unprivileged UID, not root in the host user namespace. `allowPrivilegeEscalation: false` sets the kernel `no_new_privs` bit so a setuid binary can't regain privileges. `readOnlyRootFilesystem: true` stops an attacker writing a webshell or tampering with binaries — pair it with `emptyDir` volumes mounted at the few writable paths the app needs (`/tmp`, a cache dir), which is exactly the "read-only friendly" Dockerfile habit from the fundamentals notes. `drop: ["ALL"]` then selective `add` is least privilege for kernel capabilities; most workloads need none, and a web server binding :80 needs only `NET_BIND_SERVICE` (or better, just listen on a high port and drop even that). `seccompProfile: RuntimeDefault` filters the syscall surface to the runtime's curated allowlist — off by default historically, required by `restricted`.

On SC-500 these are the **container hardening** recommendations Defender for Cloud raises and the AKS deployment-safeguards enforce: "Running containers as root user should be avoided", "Containers should run with a read only root file system", "Least privileged Linux capabilities should be enforced". Same controls, same field names — Azure Policy just wraps them.

Exam gotchas:
- `runAsNonRoot: true` only *asserts* — it makes the kubelet refuse UID 0; it does not pick a UID. If the image's default user is root and you set no `runAsUser`, the pod fails to start. Set both, or bake a non-root `USER` into the image.
- Pod-level and container-level `securityContext` both exist; container-level wins on overlap. `capabilities` and `readOnlyRootFilesystem` are container-level only.
- `privileged: true` is a superset switch that effectively disables the other hardening — it's `baseline`- and `restricted`-forbidden, and the first thing a scanner flags.

**Resources:**
- [Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) (~20 min)
- [Restrict a Container's Syscalls with seccomp](https://kubernetes.io/docs/tutorials/security/seccomp/) (~20 min)

## Enforce workload security at admission time

*Objective: `pod-admission` · OSS: Kyverno / Gatekeeper ≈ SC-500: Azure Policy for AKS · Lab: [d3-pod-security](../../labs/d3-pod-security.md)*

PSA gives you three fixed profiles at namespace granularity. Real policy needs more: "images must come from `harbor.oss500.local`", "every pod must set resource limits", "this one namespace may add `NET_ADMIN` but nothing else", "mutate every pod to add a default seccomp profile". That's the job of a **validating/mutating admission webhook** policy engine, and the two OSS choices are **Kyverno** and **OPA Gatekeeper**.

**Kyverno** writes policies as Kubernetes YAML (no new language) — this rejects any privileged pod cluster-wide:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged
spec:
  validationFailureAction: Enforce   # Enforce = block; Audit = report only
  background: true
  rules:
    - name: no-privileged-containers
      match:
        any:
          - resources: { kinds: ["Pod"] }
      validate:
        message: "Privileged containers are not allowed."
        pattern:
          spec:
            =(securityContext):
              =(privileged): "false"
            containers:
              - =(securityContext):
                  =(privileged): "false"
```

Kyverno also **mutates** (inject a default `securityContext`, add labels), **generates** (create a default NetworkPolicy per new namespace), and **verifies image signatures** (used in supply chain, `sc-admission`). **Gatekeeper** is the OPA-based engine: policy logic is Rego inside a `ConstraintTemplate`, instantiated by `Constraint` objects, and the community **Gatekeeper policy library** ships templates like `K8sPSPPrivilegedContainer` and `K8sRequiredLabels`. Gatekeeper is validate/audit-only (no mutation historically, though a mutation feature exists); Kyverno does the full validate+mutate+generate set in YAML. Both run as webhooks, so **`failurePolicy`** matters: `Fail` (default, closed) rejects requests if the webhook is down — safer but can wedge the cluster; `Ignore` (open) admits them.

Both correspond to **Azure Policy for AKS**, which *is* Gatekeeper: Azure Policy syncs constraint templates/constraints into the cluster's Gatekeeper install and reports compliance back to Defender for Cloud. When a question says "enforce that AKS pods can't run privileged via Azure Policy," the OSS-500 equivalent is precisely a Kyverno `ClusterPolicy` or a Gatekeeper `Constraint`.

Exam gotchas:
- PSA vs admission engine: PSA for the three standard profiles at namespace scope; Kyverno/Gatekeeper for custom rules, mutation, per-workload exceptions, and image/signature policy. They coexist — layer, don't choose.
- `Enforce`/`Fail` (Kyverno `validationFailureAction`, webhook `failurePolicy`) block; `Audit`/`Ignore` only report or fail open. Know which is fail-closed.
- Gatekeeper = Rego in ConstraintTemplates + Constraints, validate/audit-focused. Kyverno = Kubernetes-native YAML, also mutates/generates/verifies signatures. Azure Policy for AKS is Gatekeeper underneath.

**Resources:**
- [Kyverno — Writing Policies](https://kyverno.io/docs/writing-policies/) (~30 min)
- [OPA Gatekeeper — How to use Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/docs/howto/) (~25 min)

## Summary
| Objective | Takeaway |
|---|---|
| `pod-psa` | Pod Security Admission enforces one of three Pod Security Standards (privileged/baseline/restricted) per namespace via labels, in enforce/warn/audit modes. |
| `pod-securitycontext` | `securityContext` closes escapes: `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation:false`, `drop:[ALL]`, `seccompProfile:RuntimeDefault`. |
| `pod-admission` | Kyverno (YAML, validate+mutate+generate+verify) or Gatekeeper (Rego constraints) enforce custom policy at admission — the OSS Azure Policy for AKS. |
