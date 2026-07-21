# kind — the lab cluster

The single [kind](https://kind.sigs.k8s.io/) cluster that every in-cluster lab runs on. kind (Kubernetes IN Docker) is free, ephemeral, and disposable — `kind delete cluster` is the ultimate reset when a lab goes sideways — and it's the natural CI target, so the same `cluster.yaml` that runs on your laptop runs in a pipeline (`gov-iac`).

**Objectives:** foundation for every lab · `gov-iac` (infrastructure as code)
**Footprint:** ~2 GB RAM idle. **Time:** create ~1–2 min.

`cluster.yaml` provisions one control-plane + two workers so NetworkPolicy, scheduling, and node-level DaemonSets (Falco, kube-bench) behave like a real multi-node cluster. It labels the control-plane `ingress-ready=true` and maps host ports `8080→80` / `8443→443` so browser labs (Keycloak, Grafana, Open WebUI) are reachable on `localhost` without port-forwards.

```bash
kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml
kubectl cluster-info --context kind-oss500
lab-infra/shared/up.sh          # namespaces + ingress — run once after create
```

**Verify**
```bash
kubectl get nodes                        # 3 nodes Ready (1 control-plane, 2 workers)
kubectl get node -l ingress-ready=true   # the control-plane is ingress-ready
```

**Teardown:** `kind delete cluster --name oss500` — removes the cluster and every lab resource in it in one shot.

etcd Secret encryption-at-rest (`data-encrypt`) is layered on separately in [`../encryption`](../encryption/) so the encryption lab can show the before/after.
