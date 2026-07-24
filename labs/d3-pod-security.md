# Lab d3: Pod hardening and admission enforcement

Watch a privileged pod get rejected three different ways — by Pod Security Admission, by a hardened `securityContext`, and by a Kyverno admission policy — then prove a hardened pod runs clean.

**Objectives covered**

| id | Objective |
|---|---|
| `pod-psa` | Apply Pod Security Admission and the Pod Security Standards |
| `pod-securitycontext` | Harden securityContext: non-root, read-only root FS, dropped capabilities, seccomp |
| `pod-admission` | Enforce workload security at admission time (Kyverno / Gatekeeper) |

**SC-500 correspondence**: Azure Policy for AKS (baseline/restricted built-in initiatives), AKS deployment safeguards, and the Defender for Cloud container-hardening recommendations ("run as non-root", "read-only root filesystem", "least-privileged capabilities").

**Prerequisites**
- The shared **Phase 0 kind cluster** is up (`kind get clusters` shows `oss500`; if not: `kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml`) with [`lab-infra/shared`](../lab-infra/shared/) applied (`./up.sh`) — this creates the namespaces with the Pod Security labels.
- [`lab-infra/governance`](../lab-infra/governance/) up (`./up.sh`) for Kyverno (Part C).
- Notes read: [pod-security.md](../domains/3-compute-ai/pod-security.md)

**Estimated time**: 1.5–2 h · $0 (local)

## Challenge

Using PSA, a hardened `securityContext`, and a Kyverno `ClusterPolicy`, reach three observables — no solution here, build them in the next section:

1. **PSA rejects a privileged pod.** In the `restricted`-labeled `oss500-apps` namespace, a `--privileged=true` pod is **rejected at admission**, with a message listing *every* field the `restricted` profile finds in violation (privileged, allowPrivilegeEscalation, capabilities, runAsNonRoot, seccompProfile — all at once).
2. **A hardened pod is admitted and runs clean.** A pod satisfying the `restricted` profile — non-root, read-only root filesystem, all capabilities dropped, `RuntimeDefault` seccomp — comes up **Running**, proves `id -u` is a non-zero UID, proves a write to `/` fails with `Read-only file system`, and proves a write to a mounted `/tmp` succeeds.
3. **Kyverno enforces what PSA can't.** A pod pulling an image from a registry outside your approved allowlist is **rejected by a Kyverno `ClusterPolicy`** carrying your own custom message — a per-workload registry rule PSA has no concept of.

## Build it (guided)

### Part A — Pod Security Admission rejects a privileged pod (`pod-psa`)

1. Confirm the namespace labels: `kubectl get ns oss500-apps -o jsonpath='{.metadata.labels}'` — you should see `pod-security.kubernetes.io/enforce=restricted`.
2. Try to run a privileged pod in it:
   ```bash
   kubectl -n oss500-apps run bad --image=nginx --privileged=true \
     --restart=Never -o yaml --dry-run=client > /tmp/bad.yaml
   kubectl -n oss500-apps apply -f /tmp/bad.yaml
   ```
   → **rejected at admission** with a message like `violates PodSecurity "restricted:latest": privileged (container ... must not set securityContext.privileged=true), allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile ...`. Note it lists *every* restricted violation at once.
3. Show the mode difference: temporarily set a namespace to warn-only and observe the pod *admitted with a warning* instead of rejected:
   ```bash
   kubectl label ns oss500-apps pod-security.kubernetes.io/enforce=baseline --overwrite
   kubectl -n oss500-apps apply -f /tmp/bad.yaml   # baseline still blocks privileged, but fewer fields
   kubectl label ns oss500-apps pod-security.kubernetes.io/enforce=restricted --overwrite
   ```
   The point: `enforce` rejects; `warn`/`audit` only report. Baseline blocks the escapes; restricted also demands the hardening fields.

### Part B — write a hardened securityContext that runs clean (`pod-securitycontext`)

4. **Your turn: write the pod.** Write `/tmp/good.yaml` — a Pod in `oss500-apps` that satisfies `restricted` end to end. Work it out from the violation list you just saw in Part A; every field there needs an answer:
   - Pod-level `securityContext`: `runAsNonRoot: true` alone only tells the kubelet to *refuse* UID 0 — it doesn't pick a UID, so pair it with a `runAsUser` (any non-zero UID) or a container image that's already non-root. Add `seccompProfile: { type: RuntimeDefault }`.
   - Container-level `securityContext`: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities: { drop: ["ALL"] }`.
   - Pick an image that can actually run as non-root and listen on an unprivileged port — stock `nginx` binds `:80` and writes to root-owned paths, so it will crash under this profile. Look for an unprivileged nginx variant.
   - `readOnlyRootFilesystem: true` means anything the container writes to (temp files, cache, PID file) needs its own writable volume — `emptyDir` mounts over those paths, not the root FS.
   Apply it: `kubectl apply -f /tmp/good.yaml` → it should come up **admitted and Running**. If it CrashLoopBackOffs, the image is trying to write somewhere you haven't mounted — check its logs.
5. Prove the root FS is read-only: `kubectl -n oss500-apps exec good -- sh -c 'echo x > /root-test'` → **`Read-only file system`**. Then show the writable volume works: `kubectl -n oss500-apps exec good -- sh -c 'echo ok > /tmp/x && cat /tmp/x'` → `ok`.
6. Prove it's non-root: `kubectl -n oss500-apps exec good -- id -u` → your chosen UID, not `0`.

### Part C — write a Kyverno rule PSA can't express (`pod-admission`)

7. **Your turn: write the policy.** With Kyverno installed, write a `ClusterPolicy` (`kyverno.io/v1`) named something like `require-approved-registry` — a check no PSA profile can do, because PSA only ever looks at `securityContext` fields, never at image provenance.
   - `spec.validationFailureAction: Enforce` (not `Audit`) so it actually blocks.
   - One `validate` rule matched against `kind: Pod`, with a `pattern` that constrains `spec.containers[].image` to an allowlist — Kyverno's pattern language lets you OR multiple globs with `|` (e.g. your internal registry plus a couple of trusted upstream namespaces).
   - Give the rule a `message` your team would actually understand when a pod gets rejected.
8. `kubectl apply -f policy.yaml`, then try a pod from a disallowed registry — **run it in `oss500-demo`, not `oss500-apps`**: built-in PSA evaluates before Kyverno's validating webhook, so a `restricted`-labeled namespace would reject `evil` on PSS grounds first and you'd never see Kyverno's rejection at all.
   ```bash
   kubectl -n oss500-demo run evil --image=quay.io/evil/x --restart=Never
   ```
   → **rejected by Kyverno** with your custom message. This is the layer beyond PSA: registry allowlisting, per-workload rules, mutation.
9. **(Optional stretch, no solution given.)** Add a Kyverno *mutate* rule that injects `seccompProfile: RuntimeDefault` into any pod missing it, and confirm a pod without it comes out with it set — mutation is a Kyverno capability Gatekeeper/PSA lack.

## Verification
- A `--privileged` pod is **rejected at admission by PSA** in `oss500-apps` with a `restricted` violation listing every failed field (Part A).
- The hardened pod is **Running**, `id -u` returns `10001`, and a write to `/` returns **`Read-only file system`** while `/tmp` is writable (Part B).
- A pod from an unapproved registry is **rejected by the Kyverno ClusterPolicy** with the custom message (Part C).

## Reference solution
Build it yourself first; check after.

**Part B — the hardened pod** (`/tmp/good.yaml`):
```yaml
apiVersion: v1
kind: Pod
metadata: { name: good, namespace: oss500-apps }
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    seccompProfile: { type: RuntimeDefault }
  containers:
    - name: app
      image: nginxinc/nginx-unprivileged:stable   # non-root nginx, listens on :8080
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities: { drop: ["ALL"] }
      volumeMounts:
        - { name: tmp, mountPath: /tmp }
        - { name: cache, mountPath: /var/cache/nginx }
        - { name: run, mountPath: /var/run }
  volumes:
    - { name: tmp, emptyDir: {} }
    - { name: cache, emptyDir: {} }
    - { name: run, emptyDir: {} }
```

**Part C — the registry-allowlist policy**:
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: { name: require-approved-registry }
spec:
  validationFailureAction: Enforce
  rules:
    - name: allowed-registry
      match: { any: [{ resources: { kinds: ["Pod"] } }] }
      validate:
        message: "Images must come from harbor.oss500.local or be a known base."
        pattern:
          spec:
            containers:
              - image: "harbor.oss500.local/* | nginxinc/* | docker.io/library/*"
```

If your hardened pod CrashLoopBackOffs, it's almost always a missing `emptyDir` for a path the process still wants to write under `readOnlyRootFilesystem`. If Kyverno admits the `evil` pod anyway, check `validationFailureAction` is `Enforce`, not `Audit` — audit mode reports without blocking, same trap as PSA's `warn`.

## Teardown
- `kubectl -n oss500-apps delete pod good --ignore-not-found; kubectl delete clusterpolicy require-approved-registry --ignore-not-found`
- `cd lab-infra/governance && ./down.sh`

## What the exam asks
- PSA has three modes (enforce/warn/audit) and three profiles (privileged/baseline/restricted); enforce rejects, warn/audit report. A namespace with no labels is effectively privileged.
- `runAsNonRoot: true` makes the kubelet refuse UID 0 but doesn't pick a UID — pair with `runAsUser` or a non-root image, or the pod won't start. `readOnlyRootFilesystem` needs `emptyDir` mounts for writable paths.
- PSA is namespace-scoped and can't do per-workload exceptions, mutation, or registry rules — that's where Kyverno/Gatekeeper (the OSS Azure Policy for AKS) comes in. Kyverno mutates; Gatekeeper (Rego) validates.
