# Lab (enrichment): Kubelet attack surface

Probe the kubelet's HTTPS API on the shared `kind` cluster from inside the cluster, watch it refuse you, then read the two flags that make that refusal happen — instead of taking "the kubelet is secure" on faith.

**Type: optional enrichment.** This lab is depth beyond the SC-500 skills outline, not coverage of it — it is **not mapped to any `tracker.yaml` objective** and isn't required for readiness. Read [`labs/README.md`](README.md#enrichment-labs-optional-not-tracked) for how enrichment labs relate to the tracked catalog.

**SC-500 correspondence:** none directly. This is OSS-only depth on the Kubernetes control-plane trust model — the internals that sit *underneath* Domain 1's component/kubelet authentication ([`kubernetes-rbac.md`](../domains/1-identity-governance/kubernetes-rbac.md)) and Domain 3's runtime detection ([`runtime-security.md`](../domains/3-compute-ai/runtime-security.md)) — rather than a control with a direct Defender/Entra equivalent.

**Prerequisites**
- The shared Phase 0 kind cluster is up: `kind get clusters` shows `oss500`. If not: `kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml && lab-infra/shared/up.sh`. No dedicated `lab-infra/` component — this lab runs entirely read-only against the base cluster and the `oss500-apps` namespace from [`lab-infra/shared`](../lab-infra/shared/).
- `kubectl` and `jq`.
- Notes read: [`02-kubernetes.md` — "How the cluster is wired (and where it's soft)"](../domains/0-fundamentals/02-kubernetes.md#how-the-cluster-is-wired-and-where-its-soft). Useful but not required: [`runtime-security.md`](../domains/3-compute-ai/runtime-security.md) for where Step 4 leads next.

**Estimated time**: 30–40 min · $0 (local)

## Objectives

- Probe the kubelet's API on port **10250** from inside the cluster and observe that it is authenticated and authorized — not open — on this course's `kind` nodes.
- Read the kubelet's **live** configuration to see exactly which two settings produce that posture: `--anonymous-auth` and `--authorization-mode`.
- Read (without ever changing the cluster) what an `anonymous-auth: true` kubelet hands an unauthenticated caller, so the closed posture above reads as a deliberate control rather than an accident you can't picture.
- Connect the **CRI/containerd** boundary the kubelet hands off to, forward to what Falco and Tetragon observe in Domain 3.

## Why this is a closed-door lab, not an open one

`kind` nodes ship with `--anonymous-auth=false` and `--authorization-mode=Webhook`, and there is no read-only port (10255) to fall back on. A naive "attack the kubelet" exercise that expects to dump a pod list from an unauthenticated request will simply get **401/403** — that's the *correct* posture, not a failed lab. This lab is built around that reality: it proves the door is locked and shows you the keys that lock it, rather than picking a lock that was never open. Nothing here reconfigures the shared `kind` cluster — every other lab depends on it staying exactly as hardened as it is.

## Steps

### 1. Stand up a minimal, hardened probe pod

The probe runs in `oss500-apps` (restricted Pod Security), so it needs the same hardening shape as every other pod in this course — the one you hand-authored in [`02-kubernetes.md`](../domains/0-fundamentals/02-kubernetes.md):

```yaml
# kubelet-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: kubelet-probe
  namespace: oss500-apps
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 100          # curl_user in curlimages/curl
    seccompProfile: { type: RuntimeDefault }
  containers:
    - name: curl
      image: curlimages/curl:8.11.1
      command: ["sleep", "3600"]
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities: { drop: ["ALL"] }
      resources:
        requests: { cpu: "50m", memory: "32Mi" }
        limits: { cpu: "100m", memory: "64Mi" }
```

```bash
kubectl apply -f kubelet-probe.yaml
kubectl -n oss500-apps wait --for=condition=Ready pod/kubelet-probe --timeout=60s
```

### 2. Probe the kubelet API with no credential, then with an under-privileged one

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
NODE_IP=$(kubectl get node "$NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

# No credential at all — should be rejected before authorization is even considered
kubectl -n oss500-apps exec kubelet-probe -- \
  curl -sk -o /dev/null -w 'unauthenticated -> %{http_code}\n' "https://${NODE_IP}:10250/pods"

# The probe pod's own (default) ServiceAccount token — authenticated, but not authorized
kubectl -n oss500-apps exec kubelet-probe -- sh -c \
  'curl -sk -o /dev/null -w "default-SA token -> %{http_code}\n" \
   -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
   https://'"${NODE_IP}"':10250/pods'
```

Expect **`401`** for the first call (no identity presented — rejected at authentication) and **`403`** for the second (a real, authenticated identity — but the `oss500-apps` default ServiceAccount holds no RBAC grant on the `nodes/proxy`-style permission the kubelet's Webhook authorizer checks, so it's authenticated and still refused). The exact subresource/verb the kubelet API maps each endpoint to is documented in [Kubelet authorization](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-authn-authz/#kubelet-authorization) — worth reading once so the 403 isn't a mystery. `[depth]`

### 3. Read the live kubelet config that produces that result

Don't take the 401/403 pair on faith — read the two settings that cause it, straight from the running kubelet via the API server's node proxy (the same "everything goes through the API server" front door from the primer):

```bash
kubectl get --raw "/api/v1/nodes/${NODE}/proxy/configz" \
  | jq '{anonymous_auth: .kubeletconfig.authentication.anonymous.enabled, authorization_mode: .kubeletconfig.authorization.mode}'
```

Expect `{"anonymous_auth": false, "authorization_mode": "Webhook"}`. If you have direct Docker access to the kind node (kind nodes are themselves Docker containers), the same two fields are readable straight from the on-disk config instead of through the API server's proxy:

```bash
docker exec oss500-control-plane grep -A1 -E 'anonymous:|mode:' /var/lib/kubelet/config.yaml
```

`authorization.mode: Webhook` is the important half of the pair: it means the kubelet doesn't invent its own authorization rules — it asks the cluster's own RBAC, via a SubjectAccessReview, whether the caller may act. That's why the 403 in Step 2 is a real RBAC decision, not a kubelet-specific one.

### 4. Read (don't run) what an open kubelet hands over

The contrast that makes Step 2's 401/403 mean something: with `--anonymous-auth=true` (never set this on the shared cluster), the exact same endpoints answer any unauthenticated caller that can reach port 10250 on the node's network. This is documented kubelet API behavior, not a claim run against this cluster:

```text
# ILLUSTRATIVE ONLY — behavior of an anonymous-auth:true kubelet, not this cluster.
# Do not disable anonymous-auth on the shared oss500 cluster; every other lab depends on it.

$ curl -sk https://<node-ip>:10250/pods
# 200 OK — full PodList for every pod scheduled on this node: images, env vars,
# volume mounts, and any Secret/ConfigMap values injected as env vars in plaintext JSON.

$ curl -sk https://<node-ip>:10250/runningpods
# 200 OK — a lighter live view of what's actually running right now on the node.

$ curl -sk -X POST 'https://<node-ip>:10250/exec/<ns>/<pod>/<container>?command=sh&input=1&output=1&tty=1'
# a streaming exec session INTO that container — arbitrary command execution,
# with zero credentials presented. This is the endpoint the RBAC "pods/exec"
# subresource (see kubernetes-rbac.md) exists to gate at the API-server layer;
# an open kubelet lets you skip that gate entirely by going straight to the node.
```

`/pods` and `/runningpods` are an unauthenticated enumeration and secrets-in-env leak; `/exec` is unauthenticated remote code execution on every pod the node is running. That's the full blast radius one flag (`--anonymous-auth`) controls — see the [NSA/CISA Kubernetes Hardening Guide](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF) for the same finding as an official hardening control. `[depth]`

### 5. From the kubelet to the CRI boundary

The kubelet doesn't execute any of `/exec`, `/pods`, or container starts itself — it hands off to the container runtime over the **CRI**, containerd on this course's nodes. That handoff is the exact boundary [`runtime-security.md`](../domains/3-compute-ai/runtime-security.md) instruments: Falco and Tetragon hook the kernel underneath containerd (syscalls, kprobes, the LSM hook — see [`07-ebpf-fundamentals.md`](../domains/0-fundamentals/07-ebpf-fundamentals.md)), so they'd see the *consequences* of a leaked `/exec` session — a shell spawned in a container it didn't expect — even if the kubelet-level control that should have stopped it had failed. That's the throughline: kubelet authn/authz is the first gate, runtime detection is the net underneath it if that gate is ever bypassed.

## Verification

- Step 2's unauthenticated request to `https://${NODE_IP}:10250/pods` returns **`401`**, and the same request with the default ServiceAccount's token returns **`403`** — a concrete, observed denial, not a description of one.
- Step 3's `configz` read confirms `anonymous_auth: false` and `authorization_mode: "Webhook"` on the **live** cluster — the flags that produce exactly the 401/403 pair above, read rather than assumed.
- If either curl in Step 2 instead returns `200` with a pod list, stop and treat it as a finding to report (per the catalog's validation-status discipline in [`labs/README.md`](README.md)), not as this lab working as designed — it would mean the shared cluster's kubelet posture drifted from the hardened default.

## Teardown

```bash
kubectl -n oss500-apps delete pod kubelet-probe --ignore-not-found
```

No other resources are created; the base `oss500` cluster and its other namespaces are untouched.

## Validation status — host-pending

This lab's exact HTTP status codes (`401`/`403`), the `configz` JSON shape, and the kubelet-authorization subresource mapping in Step 2 have not yet been executed end-to-end on a host by the author — the command shapes follow documented kubelet API and authorization behavior (linked inline above). No specific kind release is pinned in this course (see [`TOOLS.md`](../TOOLS.md)); Steps 2–3 deliberately *read* the live cluster's config rather than asserting a fixed value, so they hold across kind/kubelet versions — if your output differs from what's described here, that divergence is itself the finding this lab is designed to surface. Report a mismatch rather than assuming the write-up is wrong.
