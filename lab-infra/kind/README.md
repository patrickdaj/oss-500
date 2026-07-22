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

## Cilium mode (the cloud-network-fabric lab)

The [d2-network-fabric](../../labs/d2-network-fabric.md) lab needs the eBPF dataplane (egress gateway, DNS/FQDN + host firewall, Hubble), so it runs on a variant cluster created from [`cluster-cilium.yaml`](cluster-cilium.yaml) **instead of** `cluster.yaml`:

```bash
kind create cluster --name oss500 --config lab-infra/kind/cluster-cilium.yaml
lab-infra/network/cilium/up.sh    # installs Cilium as the CNI, then the fabric policies
lab-infra/shared/up.sh            # namespaces + ingress (after Cilium is Ready)
```

`cluster-cilium.yaml` is the same topology with three networking changes: `disableDefaultCNI: true` (Cilium becomes the CNI — `fab-cni`), `kubeProxyMode: none` (Cilium replaces kube-proxy so BPF masquerade / egress gateway work), and an explicit `podSubnet`. Every other lab still runs on this cluster; only the fabric controls are added. This is an **opt-in mode**, not the default — bring up the plain `cluster.yaml` for all the other labs.

> **eBPF-fussy hosts:** egress gateway + host firewall want a modern Linux kernel with the right eBPF features. On Docker Desktop (macOS/Windows, the LinuxKit VM) most works, but if egress-gateway SNAT or the host firewall misbehaves, run kind inside a Linux VM — [Lima](https://lima-vm.io/) on macOS or any Linux VM — exactly the fallback the Falco/Tetragon eBPF labs document. Cilium version is pinned in [`../network/cilium/`](../network/cilium/).
