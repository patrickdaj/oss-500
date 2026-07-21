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
- kind cluster up (`kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml`) and [`lab-infra/shared`](../lab-infra/shared/) applied (`./up.sh`) — this creates the namespaces with the Pod Security labels.
- [`lab-infra/governance`](../lab-infra/governance/) up (`./up.sh`) for Kyverno (Part C).
- Notes read: [pod-security.md](../domains/3-compute-ai/pod-security.md)

**Estimated time**: 1.5–2 h · $0 (local)

## Steps

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

### Part B — A hardened securityContext runs clean (`pod-securitycontext`)

4. Apply a fully hardened pod that satisfies `restricted`:
   ```yaml
   # /tmp/good.yaml
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
   `kubectl apply -f /tmp/good.yaml` → **admitted and Running**.
5. Prove the root FS is read-only: `kubectl -n oss500-apps exec good -- sh -c 'echo x > /root-test'` → **`Read-only file system`**. Then show the writable volume works: `kubectl -n oss500-apps exec good -- sh -c 'echo ok > /tmp/x && cat /tmp/x'` → `ok`.
6. Prove it's non-root: `kubectl -n oss500-apps exec good -- id -u` → `10001`, not `0`.

### Part C — Kyverno enforces a custom rule PSA can't (`pod-admission`)

7. With Kyverno installed, apply a policy that requires images to come only from the approved registry and disallows `:latest` — something PSA cannot express:
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
8. `kubectl apply -f policy.yaml`, then try a pod from a disallowed registry (`kubectl -n oss500-apps run evil --image=quay.io/evil/x --restart=Never`) → **rejected by Kyverno** with your custom message. This is the layer beyond PSA: registry allowlisting, per-workload rules, mutation.
9. (Optional) Add a Kyverno *mutate* rule that injects `seccompProfile: RuntimeDefault` into any pod missing it, and confirm a pod without it comes out with it set — mutation is a Kyverno capability Gatekeeper/PSA lack.

## Verification
- A `--privileged` pod is **rejected at admission by PSA** in `oss500-apps` with a `restricted` violation listing every failed field (Part A).
- The hardened pod is **Running**, `id -u` returns `10001`, and a write to `/` returns **`Read-only file system`** while `/tmp` is writable (Part B).
- A pod from an unapproved registry is **rejected by the Kyverno ClusterPolicy** with the custom message (Part C).

## Teardown
- `kubectl -n oss500-apps delete pod good --ignore-not-found; kubectl delete clusterpolicy require-approved-registry --ignore-not-found`
- `cd lab-infra/governance && ./down.sh`

## What the exam asks
- PSA has three modes (enforce/warn/audit) and three profiles (privileged/baseline/restricted); enforce rejects, warn/audit report. A namespace with no labels is effectively privileged.
- `runAsNonRoot: true` makes the kubelet refuse UID 0 but doesn't pick a UID — pair with `runAsUser` or a non-root image, or the pod won't start. `readOnlyRootFilesystem` needs `emptyDir` mounts for writable paths.
- PSA is namespace-scoped and can't do per-workload exceptions, mutation, or registry rules — that's where Kyverno/Gatekeeper (the OSS Azure Policy for AKS) comes in. Kyverno mutates; Gatekeeper (Rego) validates.
