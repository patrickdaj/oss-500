# Fundamentals: Kubernetes primitives

Ramp notes — no exam objective maps here. Enough Kubernetes to read every manifest and `kubectl` command in the labs without friction.

## The model

Kubernetes is a declarative control loop. You submit desired state (objects) to the **API server**; controllers reconcile actual state toward it. The **control plane** (API server, scheduler, controller-manager, etcd) makes decisions; **nodes** (kubelet + container runtime) run the pods.

`etcd` stores all cluster state — including Secrets. By default etcd data is *not encrypted at rest*, which is exactly the gap `data-encrypt` (Phase 2) closes.

## Objects you'll use constantly

- **Pod** — one or more containers sharing a network namespace and volumes. The unit of scheduling.
- **Deployment / ReplicaSet** — declarative, self-healing set of pod replicas.
- **Service** — stable virtual IP / DNS name load-balancing to pods by label selector. East-west traffic flows Service→pod, which is what NetworkPolicy (`net-policy`) governs.
- **ConfigMap / Secret** — configuration and sensitive data injected as env vars or mounted files. **A Secret is only base64-encoded, not encrypted** — anyone who can `get secrets` in the namespace can read it. RBAC (`rbac-*`) and etcd encryption are what actually protect it.
- **Namespace** — a scope for names, RBAC, quotas, and NetworkPolicy. The primary blast-radius boundary.
- **Labels / selectors** — key/value tags; nearly every control (Services, NetworkPolicy, Pod Security Admission) targets workloads by label.

## kubectl survival kit

```bash
kubectl get pods -A                     # everything, all namespaces
kubectl describe pod <name> -n <ns>     # events + why it's not Running
kubectl logs <pod> -n <ns> [-c <ctr>]   # container logs
kubectl apply -f manifest.yaml          # declarative create/update
kubectl auth can-i list secrets -n <ns> # RBAC check (previews Phase 1)
kubectl get events -n <ns> --sort-by=.lastTimestamp
```

## Hands-on: deploy, expose, scale (on your kind cluster)

Run these against the `oss500` cluster from Phase 0 — no minikube, no separate cluster:

```bash
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl scale deployment nginx --replicas=3
kubectl get pods,svc
```

Watch the ReplicaSet bring up three pods. Before cleaning up, read back what that imperative command actually built:

```bash
kubectl get deploy nginx -o yaml
```

That prints the full `Deployment` object — `apiVersion`, `metadata`, `spec.replicas`, `spec.template` (the pod spec, with the `nginx` image and its default `securityContext` of nothing set), the works. `kubectl create deployment` didn't skip authoring a manifest; it authored one for you and applied it in one step. Every hand-written manifest in this course is this exact shape — which is why the next section has you write one yourself instead of letting the imperative command choose the (unhardened) defaults.

Clean up: `kubectl delete deployment,svc nginx`.

## Author a hardened pod manifest

The `-o yaml` above shows a Deployment with no `securityContext` at all — root user, writable root filesystem, every Linux capability, no resource limits. That's the default posture, and it's why Domain 3's admission labs (`pod-psa`, `pod-securitycontext`) exist. Here you author the fix by hand, once, before those labs assume you already can.

Save this as `hardened-nginx.yaml`. It runs as a fixed non-root UID, mounts its root filesystem read-only, drops every Linux capability, caps its CPU/memory, and probes its own readiness:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hardened-nginx
  namespace: oss500-apps
spec:
  securityContext:
    runAsNonRoot: true       # kubelet refuses to start the container as UID 0
    runAsUser: 10001
  containers:
    - name: nginx
      image: nginxinc/nginx-unprivileged:stable   # non-root nginx build, listens on :8080
      ports:
        - containerPort: 8080
      securityContext:
        allowPrivilegeEscalation: false   # no_new_privs — no regaining privilege via setuid
        readOnlyRootFilesystem: true      # writes outside the mounted volumes below fail
        capabilities:
          drop: ["ALL"]                   # start from zero Linux capabilities
      resources:
        requests: { cpu: "100m", memory: "64Mi" }
        limits: { cpu: "200m", memory: "128Mi" }
      readinessProbe:
        httpGet: { path: /, port: 8080 }
        initialDelaySeconds: 3
      volumeMounts:                       # the read-only root FS needs explicit writable paths
        - { name: tmp, mountPath: /tmp }
        - { name: cache, mountPath: /var/cache/nginx }
        - { name: run, mountPath: /var/run }
  volumes:
    - { name: tmp, emptyDir: {} }
    - { name: cache, emptyDir: {} }
    - { name: run, emptyDir: {} }
```

Apply it and prove the hardening is enforced, not just declared:

```bash
kubectl apply -f hardened-nginx.yaml
kubectl get pod hardened-nginx -n oss500-apps                       # Running, not CrashLoopBackOff
kubectl exec -n oss500-apps hardened-nginx -- id -u                 # 10001 — not root
kubectl exec -n oss500-apps hardened-nginx -- sh -c 'echo x > /root-test'
# sh: can't create /root-test: Read-only file system
```

That last command is the point: `readOnlyRootFilesystem: true` isn't a note in a YAML file the cluster ignores — the write is actually denied. Clean up when done: `kubectl delete pod hardened-nginx -n oss500-apps`.

## ServiceAccounts and the token model

Every pod runs as a **ServiceAccount** (the `default` SA if none is set). The API server projects a short-lived, audience-scoped token into the pod at `/var/run/secrets/kubernetes.io/serviceaccount/token`. That token *is* the workload's identity — the foundation of Kubernetes RBAC and of workload-identity federation (`wi-*`) where the cluster's OIDC issuer lets Vault or a cloud trust that token. Understand this now; Phase 1 builds directly on it.

## RBAC in 10 minutes

A 10-minute orientation, not the deep dive — Phase 1's [kubernetes-rbac.md](../1-identity-governance/kubernetes-rbac.md) covers default ClusterRoles, escalation verbs, and auditing at full depth. Here, just enough to be dangerous.

Four objects, and the whole model is knowing which scope each covers:

- **Role** — a namespaced set of permission rules: `apiGroups` × `resources` × `verbs`.
- **ClusterRole** — the same shape at cluster scope (also reusable inside one namespace, see below).
- **RoleBinding** — attaches a Role *or* ClusterRole to **subjects** (`ServiceAccount`, `User`, `Group`) within one namespace.
- **ClusterRoleBinding** — attaches a ClusterRole to subjects across the whole cluster.

The **binding**, not the role, decides the scope: bind a ClusterRole with a RoleBinding and it's namespace-limited; bind the same ClusterRole with a ClusterRoleBinding and it's cluster-wide.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { name: pod-reader, namespace: oss500-apps }
rules:
  - apiGroups: [""]                    # "" is the core API group
    resources: ["pods"]
    verbs: ["get", "list", "watch"]     # read-only — no create/delete/exec
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: default-pod-reader, namespace: oss500-apps }
subjects:
  - kind: ServiceAccount
    name: default
    namespace: oss500-apps
roleRef: { kind: Role, name: pod-reader, apiGroup: rbac.authorization.k8s.io }
```

Apply it, then check the effective permission with the tool you'll use constantly from here on — don't assume, test:

```bash
kubectl apply -f pod-reader.yaml
kubectl auth can-i list pods -n oss500-apps --as=system:serviceaccount:oss500-apps:default    # yes
kubectl auth can-i list secrets -n oss500-apps --as=system:serviceaccount:oss500-apps:default # no
```

That's the whole preview: rules declare *what*, a binding decides *who* and *at what scope*, and `can-i` proves the answer instead of assuming it.

## Security-relevant defaults to remember

- Secrets are base64, not encrypted (fix: etcd encryption + RBAC + a secrets manager).
- Pods can talk to any other pod by default — there is no network segmentation until you add NetworkPolicy.
- The `default` ServiceAccount and overly broad RBAC are common privilege-escalation paths.
- Nothing stops a pod from running as root with host mounts unless admission control (Pod Security Admission / Kyverno) says no.

## Self-check

1. Why is a Kubernetes Secret not "secure" out of the box, and what three controls in this course harden it?
2. Where does a pod's identity come from, and how does that token become the basis for RBAC?
3. By default, can a pod in namespace A reach a pod in namespace B? What object changes that?

## Primary sources
- [Kubernetes — Concepts: Overview](https://kubernetes.io/docs/concepts/overview/)
- [Kubernetes Basics — interactive tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/) — concepts / interactive only. It provisions its cluster with **minikube**, which this course never uses; do ALL hands-on on your `kind` cluster (see [Phase 0](../../plan/phase0-fundamentals.md)) using the commands below, not minikube.
- [kubectl reference](https://kubernetes.io/docs/reference/kubectl/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) — the `runAsNonRoot`/`readOnlyRootFilesystem`/`capabilities` fields used in the hardened-pod manifest above
- [Kubernetes — Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) — Role/ClusterRole/RoleBinding/ClusterRoleBinding definitions behind the "RBAC in 10 minutes" section
