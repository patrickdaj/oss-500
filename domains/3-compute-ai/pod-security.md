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

The three modes matter: **`enforce`** rejects the pod at admission, **`warn`** returns a client warning but admits it, **`audit`** writes an annotation to the audit log. A common rollout is `warn`+`audit` at `restricted` first to find what breaks, then flip `enforce`. Each mode takes an independent profile *and* an independent `-version` pin (`enforce-version: v1.31`, or `latest`) — pinning a version freezes the checks so a cluster upgrade that tightens the `restricted` profile can't silently start rejecting previously-admitted pods. Note the granularity gap: PSA enforces at the *namespace* level and can't make per-workload exceptions — if one Deployment in a `restricted` namespace legitimately needs a capability, PSA can't grant just that; you either relax the whole namespace or move the workload. That limitation is exactly why Kyverno/Gatekeeper (`pod-admission`) exists alongside PSA.

A crucial mechanism detail: **PSA only evaluates the Pod spec at admission**, so it checks Deployments/StatefulSets/Jobs *indirectly* via the pods their controllers create. If a Deployment template violates `restricted`, the Deployment object itself is admitted (only `warn`/`audit` fire on it) but the ReplicaSet controller's pod-create calls are rejected — you get a healthy-looking Deployment with zero running pods and rejection events on the ReplicaSet. That "Deployment accepted, pods silently never start" failure mode is a classic PSA gotcha. Also note PSA is *non-mutating*: it will not inject a `seccompProfile` or drop capabilities for you, so a `restricted` namespace requires the workload author to have already set every hardening field (see `pod-securitycontext`); a bare pod fails. PSA also honors **exemptions** configured cluster-wide in the `AdmissionConfiguration` (by username, RuntimeClass, or namespace) — useful for system namespaces like `kube-system`, which ships unlabelled and effectively `privileged`.

In OSS-500 the standards are already wired in [`shared/namespaces.yaml`](../../lab-infra/shared/namespaces.yaml): `oss500-apps` and `oss500-identity` enforce `restricted`, `oss500-secrets` and `oss500-monitoring` enforce `baseline`, and `oss500-security` is deliberately `privileged` because Falco, Tetragon and friends need host mounts and eBPF — the documented exception. On SC-500, this maps to **AKS built-in policy initiatives** ("Kubernetes cluster pods should only use allowed security capabilities", the *baseline*/*restricted* Azure Policy sets) delivered via **Azure Policy for AKS**, which is itself Gatekeeper under the hood.

Exam gotchas:
- PSA has three *modes* (enforce/warn/audit) and three *profiles* (privileged/baseline/restricted). Don't conflate them — you can run `warn:restricted` while `enforce:baseline`.
- PSA is namespace-scoped and label-driven; it can't do per-pod exemptions or mutate resources. That's the boundary where you reach for an admission engine.
- The `privileged` profile is the *absence* of a control, not a control. A namespace with no PSA labels is effectively `privileged`.
- PSA validates *pods*, not controllers — a violating Deployment is admitted while its pods are silently rejected. Debug with the ReplicaSet events, not the Deployment status.
- **PodSecurityPolicy (PSP) is gone** — removed in Kubernetes 1.25 and replaced by PSA. If a question offers PSP as an answer for a current cluster, it's the distractor; the migration path is PSP → PSA (+ Kyverno/Gatekeeper for what PSA can't express).

**Resources:**
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) `[depth]` (~20 min)
- [Pod Security Admission — concepts](https://kubernetes.io/docs/concepts/security/pod-security-admission/) `[depth]` (~15 min)
- [Enforce Pod Security Standards with namespace labels](https://kubernetes.io/docs/tasks/configure-pod-security-admission/enforce-standards-namespace-labels/) `[depth]` (~15 min)
- [Migrate from PodSecurityPolicy to PSA](https://kubernetes.io/docs/tasks/configure-pod-security-admission/migrate-from-psp/) `[depth]` (~20 min)
- [Azure Policy for AKS — built-in initiatives & Gatekeeper](https://learn.microsoft.com/azure/aks/use-azure-policy) `[depth]` (~20 min)

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

Two more fields round out the `restricted` picture. `procMount` must stay at its `Default` (masked) value so `/proc` paths that leak host state are hidden. And **`runAsGroup` / `fsGroup`** matter for file ownership: `fsGroup` sets the group that owns mounted volumes so a non-root UID can actually write to them — forget it and a `readOnlyRootFilesystem: true` pod with a non-root user often crashes trying to write its one `emptyDir` cache. That interplay — non-root UID + read-only root FS + `fsGroup`-owned writable volume — is the single most common "hardened the pod, now it `CrashLoopBackOff`s" failure mode.

Under the hood these fields map to Linux primitives: capabilities are the 40-odd `CAP_*` bits (`man 7 capabilities`), `allowPrivilegeEscalation: false` sets the kernel `no_new_privs` flag, and `seccompProfile: RuntimeDefault` loads containerd/CRI-O's curated BPF syscall allowlist (roughly 300 of ~450 syscalls permitted; the rest return `EPERM`). A custom `type: Localhost` profile points at a JSON seccomp file on the node for tighter filtering, but `RuntimeDefault` is what `restricted` requires and what you should reach for first.

On SC-500 these are the **container hardening** recommendations Defender for Cloud raises and the AKS deployment-safeguards enforce: "Running containers as root user should be avoided", "Containers should run with a read only root file system", "Least privileged Linux capabilities should be enforced", "Privileged containers should be avoided". Same controls, same field names — Azure Policy just wraps them, and they also map directly to CIS Kubernetes Benchmark section 5 (Pod Security).

Exam gotchas:
- `runAsNonRoot: true` only *asserts* — it makes the kubelet refuse UID 0; it does not pick a UID. If the image's default user is root and you set no `runAsUser`, the pod fails to start. Set both, or bake a non-root `USER` into the image.
- Pod-level and container-level `securityContext` both exist; container-level wins on overlap. `capabilities`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation`, and `privileged` are container-level only; `fsGroup`/`runAsGroup`/`supplementalGroups` are pod-level only.
- `privileged: true` is a superset switch that effectively disables the other hardening — it's `baseline`- and `restricted`-forbidden, and the first thing a scanner flags.
- `readOnlyRootFilesystem: true` without an `emptyDir` at the app's writable paths (and the right `fsGroup`) is the top cause of a hardened pod crash-looping. The fix is a writable volume, not relaxing the control.
- Dropping `ALL` capabilities and adding back only `NET_BIND_SERVICE` is least privilege; a web server on a high port (`:8080`) needs *zero* added caps — prefer that over adding any.

**Resources:**
- [Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) `[depth]` (~20 min)
- [Restrict a Container's Syscalls with seccomp](https://kubernetes.io/docs/tutorials/security/seccomp/) `[depth]` (~20 min)
- [Linux capabilities — `man 7 capabilities`](https://man7.org/linux/man-pages/man7/capabilities.7.html) `[depth]` (~15 min)
- [CIS Kubernetes Benchmark (section 5, Pod Security)](https://www.cisecurity.org/benchmark/kubernetes) `[depth]` (~20 min)
- [NSA/CISA Kubernetes Hardening Guidance](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF) `[depth]` (~30 min)

## Enforce workload security at admission time

*Objective: `pod-admission` · OSS: Kyverno / Gatekeeper ≈ SC-500: Azure Policy for AKS · Lab: [d3-pod-security](../../labs/d3-pod-security.md)*

PSA gives you three fixed profiles at namespace granularity. Real policy needs more: "images must come from `harbor.oss500.local`", "every pod must set resource limits", "this one namespace may add `NET_ADMIN` but nothing else", "mutate every pod to add a default seccomp profile". That's the job of a **validating/mutating admission webhook** policy engine — the two OSS choices are **Kyverno** (Kubernetes-native YAML) and **OPA Gatekeeper** (Rego). Their internals are a cross-cutting governance concern taught canonically in Domain 1 — authoring models, `Enforce` vs `Audit`, webhook `failurePolicy` fail-open/closed, system-namespace exemptions, and the "Azure Policy for AKS *is* Gatekeeper" anchor all live in [`gov-gatekeeper`](../1-identity-governance/governance.md#enforce-organizational-policy-with-opa-gatekeeper-constraints) and [`gov-kyverno`](../1-identity-governance/governance.md#enforce-and-mutate-resources-with-kyverno-policies). What follows is only the pod-specific delta: *why* you reach for an engine beyond PSA, and *how* mutation lets it auto-harden pods.

**PSA vs. policy engine — layer, don't choose.** PSA applies one of three *fixed* profiles at *namespace* scope; it can't express a custom rule ("images from `harbor.oss500.local` only"), grant a per-workload exception (one Deployment that legitimately needs `NET_ADMIN`), or gate images and signatures. Kyverno/Gatekeeper do exactly those things — custom rules, per-workload exceptions, image/signature policy — and run *alongside* PSA rather than replacing it. Use PSA for the broad namespace baseline and the engine wherever the requirement is narrower or broader than a whole-namespace profile.

**Mutation runs before validation.** In the admission chain a mutating webhook fires before any validating webhook (and before PSA's own check), so a Kyverno **mutate** rule that injects a default `securityContext` or seccomp profile can bring a *bare* pod into compliance *before* PSA or a validate rule judges it. That ordering is how you auto-harden pods PSA would otherwise reject — you remediate them at admission instead of failing them. Kyverno also ships a curated **Pod Security policy set** that reproduces the `restricted` profile as individual policies, giving per-rule granularity that namespace-level PSA can't.

Exam gotchas:
- PSA vs admission engine: PSA for the three standard profiles at namespace scope; Kyverno/Gatekeeper for custom rules, mutation, per-workload exceptions, and image/signature policy. They coexist — layer, don't choose.
- Mutation runs before validation — use a Kyverno mutate rule to inject hardening defaults so pods pass PSA instead of failing it.
- For engine internals (authoring models, `Enforce`/`Audit`, `failurePolicy`, system-namespace exemptions, Azure Policy for AKS), see `gov-gatekeeper`/`gov-kyverno` in [governance.md](../1-identity-governance/governance.md) — they're single-sourced there, not re-derived here.

**Resources:**
- [Kyverno — Pod Security policy set](https://kyverno.io/policies/pod-security/) `[depth]` (~15 min)
- [AKS deployment safeguards](https://learn.microsoft.com/azure/aks/deployment-safeguards) `[depth]` (~15 min)

## Summary
| Objective | Takeaway |
|---|---|
| `pod-psa` | Pod Security Admission enforces one of three Pod Security Standards (privileged/baseline/restricted) per namespace via labels, in enforce/warn/audit modes. |
| `pod-securitycontext` | `securityContext` closes escapes: `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation:false`, `drop:[ALL]`, `seccompProfile:RuntimeDefault`. |
| `pod-admission` | Kyverno (YAML, validate+mutate+generate+verify) or Gatekeeper (Rego constraints) enforce custom policy at admission — the OSS Azure Policy for AKS. |
