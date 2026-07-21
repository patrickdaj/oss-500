# Fundamentals: kind, Helm, and the IaC loop

Ramp notes — no exam objective maps here. This is the toolchain every lab uses.

## kind — Kubernetes in Docker

[kind](https://kind.sigs.k8s.io/) runs a Kubernetes cluster inside Docker containers. It's the lab cluster for this course because it's free, ephemeral, and disposable — `kind delete cluster` is the ultimate reset when a lab goes sideways. The cluster definition lives in [lab-infra/](../lab-infra/) so the whole environment is reproducible from a clean clone.

```bash
kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml
kubectl cluster-info --context kind-oss500
kind delete cluster --name oss500          # full teardown
```

kind is also the natural CI target — the same cluster config that runs on your laptop runs in a pipeline. That's the "infrastructure as code doubles as study material" idea (`gov-iac`) in miniature.

## Helm — packaged, reviewable deployments

Helm installs **charts** (packaged manifests) parameterized by **values**. For security work its best feature is `helm template`: render a chart to plain YAML and *read the manifests before applying them* — you can see the `securityContext`, RBAC, and NetworkPolicy a chart ships with.

```bash
helm repo add <name> <url> && helm repo update
helm template <release> <chart> -f values.yaml   # render without installing — review it
helm install <release> <chart> -f values.yaml -n <ns> --create-namespace
helm upgrade <release> <chart> -f values.yaml -n <ns>
helm uninstall <release> -n <ns>
```

Many labs use Helm values files with **security-relevant settings commented against the objective they implement** — reading those values *is* study.

## The deploy → verify → destroy loop

Every lab component ships an `up.sh` and `down.sh` (thin wrappers over Helm/kubectl/compose) plus a `README.md`. The discipline:

1. **Deploy** — `./up.sh` (or `helm install`, `kubectl apply`, `docker compose up`).
2. **Verify** — confirm the security control actually works (a denied request, a fired alert, a blocked connection). Deploying the tool is not the goal; *proving the control* is.
3. **Destroy** — `./down.sh`, then confirm no leftovers: `kubectl get all -A`, `docker ps`, `helm list -A`.

Leftover components are the #1 resource drain on a laptop. Bring up only what the current lab needs.

## IaC as a security control

Provisioning security controls as code (`gov-iac`) is itself an SC-500 objective. Benefits you'll rely on: the environment is reviewable (diff the manifests), reproducible (clean clone → same cluster), and the controls are version-controlled. Where a manifest sets `readOnlyRootFilesystem: true` or a default-deny NetworkPolicy, a comment names the objective it exercises so the code teaches while it deploys.

## Self-check

1. Create the kind cluster from the lab-infra config, then delete it and confirm the containers are gone.
2. Use `helm template` to render a chart and find its `securityContext` without installing anything.
3. Describe the three steps of the deploy→verify→destroy loop and why "verify" is the point.

## Primary sources
- [kind — Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [Helm — documentation](https://helm.sh/docs/)
- [Terraform — Intro](https://developer.hashicorp.com/terraform/intro) · [install](https://developer.hashicorp.com/terraform/install)
- [Kubernetes — Configuration best practices](https://kubernetes.io/docs/concepts/configuration/overview/)
