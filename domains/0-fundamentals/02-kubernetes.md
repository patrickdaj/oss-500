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

## ServiceAccounts and the token model

Every pod runs as a **ServiceAccount** (the `default` SA if none is set). The API server projects a short-lived, audience-scoped token into the pod at `/var/run/secrets/kubernetes.io/serviceaccount/token`. That token *is* the workload's identity — the foundation of Kubernetes RBAC and of workload-identity federation (`wi-*`) where the cluster's OIDC issuer lets Vault or a cloud trust that token. Understand this now; Phase 1 builds directly on it.

## Security-relevant defaults to remember

- Secrets are base64, not encrypted (fix: etcd encryption + RBAC + a secrets manager).
- Pods can talk to any other pod by default — there is no network segmentation until you add NetworkPolicy.
- The `default` ServiceAccount and overly broad RBAC are common privilege-escalation paths.
- Nothing stops a pod from running as root with host mounts unless admission control (Pod Security Admission / Kyverno) says no.

## Self-check

1. Why is a Kubernetes Secret not "secure" out of the box, and what three controls in this course harden it?
2. Where does a pod's identity come from, and how does that token become the basis for RBAC?
3. By default, can a pod in namespace A reach a pod in namespace B? What object changes that?
