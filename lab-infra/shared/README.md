# shared — namespaces, Pod Security, and ingress

Cross-cutting cluster bootstrap that every lab depends on: the `oss500-*` namespaces (each pre-labelled with a Pod Security Admission level), the common `app.kubernetes.io/part-of: oss500` label for one-command teardown, and the ingress controller.

**Objectives:** foundation for all labs · `pod-psa` (namespace PSA labels) · `net-ingress` (ingress)
**Footprint:** ~300 MB RAM (ingress-nginx). **Time:** up ~1–2 min.

Run once, right after the kind cluster is created:

```bash
lab-infra/shared/up.sh
```

This applies [`namespaces.yaml`](namespaces.yaml) and installs the kind flavour of ingress-nginx (reachable on `localhost:8080/8443`).

The namespaces encode the Pod Security posture the labs assume (`pod-psa`):

| Namespace | PSA enforce | Why |
|---|---|---|
| `oss500-identity` | restricted | Keycloak/PAM run unprivileged |
| `oss500-secrets` | baseline | Vault/cert-manager need a little latitude |
| `oss500-apps` | restricted | demo workloads must be hardened |
| `oss500-security` | privileged | Falco/Tetragon/Kubescape legitimately need host + eBPF access — the documented exception |
| `oss500-monitoring` | baseline | Prometheus/Grafana/Loki |

**Verify**
```bash
kubectl get ns -l app.kubernetes.io/part-of=oss500
kubectl get pods -n ingress-nginx           # controller Running
# find everything for teardown at any time:
kubectl get all -A -l app.kubernetes.io/part-of=oss500
```

**Teardown:** namespaces and ingress go away with `kind delete cluster --name oss500`. To remove just these: `kubectl delete -f lab-infra/shared/namespaces.yaml`.

## Cilium mode

For the [d2-network-fabric](../../labs/d2-network-fabric.md) lab the cluster is created from [`../kind/cluster-cilium.yaml`](../kind/cluster-cilium.yaml) and Cilium is installed as the CNI (see [`../network/cilium/`](../network/cilium/)). Install Cilium **before** running this bootstrap — with `disableDefaultCNI` the nodes stay `NotReady` until a CNI is present, and ingress-nginx can't schedule until then:

```bash
kind create cluster --name oss500 --config lab-infra/kind/cluster-cilium.yaml
lab-infra/network/cilium/up.sh    # Cilium CNI + fabric policies -> nodes go Ready
lab-infra/shared/up.sh            # then namespaces + ingress as usual
```

The `oss500-*` namespaces and their PSA levels are unchanged in Cilium mode; the fabric lab uses `oss500-apps` for its client workloads.
