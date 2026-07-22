#!/usr/bin/env bash
# Reference solution — install Cilium as the cluster CNI and bring up the
# cloud-network-fabric controls (egress gateway, FQDN + host firewall, Hubble).
# Build your own from labs/d2-network-fabric.md first; run this to check/compare.
#
# Prereqs: a kind cluster created in Cilium mode:
#   kind create cluster --name oss500 --config lab-infra/kind/cluster-cilium.yaml
# plus `helm`, `kubectl`, `docker`, and (optional) the `cilium` CLI.
# SC-500 correspondence: VNet dataplane + NAT gateway + Azure Firewall + flow logs.
# Objectives: fab-cni fab-egress fab-fqdn fab-flowlogs
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER=oss500
CILIUM_VERSION="1.16.5"          # pinned: egress gw + FQDN + host fw + Hubble on kind
NS=oss500-apps

echo "==> fab-cni: installing Cilium ${CILIUM_VERSION} as the CNI"
# kubeProxyReplacement needs the API server reachable directly (kube-proxy is gone):
# use the kind control-plane container IP on the docker network.
API_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${CLUSTER}-control-plane")"
echo "    kube-apiserver at ${API_IP}:6443 (kubeProxyReplacement)"

helm repo add cilium https://helm.cilium.io >/dev/null
helm repo update >/dev/null
helm upgrade --install cilium cilium/cilium \
  --version "${CILIUM_VERSION}" \
  --namespace kube-system \
  -f "$here/values.yaml" \
  --set k8sServiceHost="${API_IP}" \
  --set k8sServicePort=6443 \
  --set cluster.name="${CLUSTER}" \
  --wait --timeout 5m

echo "==> Waiting for Cilium to be Ready (nodes go Ready once the CNI is up)"
kubectl -n kube-system rollout status ds/cilium --timeout=180s

echo "==> fab-egress: label a worker as the egress gateway node"
GW_NODE="${CLUSTER}-worker"
kubectl label node "${GW_NODE}" egress-gateway=true --overwrite

echo "==> Ensuring OSS-500 namespaces exist (PSA labels) before demo workloads"
# Cilium must be installed before shared/up.sh (its ingress needs a CNI), but the
# demo clients land in oss500-apps — so apply the namespaces here (idempotent; a
# later shared/up.sh re-apply is a no-op). oss500-apps is PSA "restricted", which
# is why manifests/clients.yaml runs non-root with all caps dropped.
kubectl apply -f "$here/../../shared/namespaces.yaml"

echo "==> Deploying fabric demo workloads into ${NS}  [fab-egress fab-fqdn]"
kubectl apply -f "$here/manifests/clients.yaml"
kubectl -n "$NS" wait --for=condition=ready pod -l app.kubernetes.io/part-of=oss500 --timeout=120s || true

echo "==> Applying fabric policies  [fab-egress fab-fqdn]"
# egress-gateway.yaml pins pods labelled egress=gateway to the gateway node's IP;
# fqdn-allow.yaml is a DNS/FQDN allowlist. host-firewall.yaml is applied by hand in
# the lab (it filters the node) — NOT auto-applied here, to avoid locking out kind.
kubectl apply -f "$here/policies/egress-gateway.yaml"
kubectl apply -f "$here/policies/fqdn-allow.yaml"

cat <<EOF

==> Cilium mode up.  Fabric controls:
    fab-egress:   an external listener sees a FIXED source IP for the egress-client pod
                  (docker run a listener on the 'kind' network; set its IP in
                  policies/egress-gateway.yaml destinationCIDRs) — see the lab.
    fab-fqdn:     kubectl -n ${NS} exec deploy/fqdn-client -- curl -sS https://docs.cilium.io -o /dev/null -w '%{http_code}\n'   # allowed
                  kubectl -n ${NS} exec deploy/fqdn-client -- curl -sS --max-time 5 https://example.com -o /dev/null -w '%{http_code}\n'  # DENIED
    fab-flowlogs: cilium hubble port-forward &   then   hubble observe --namespace ${NS} --verdict DROPPED
    host fw:      kubectl apply -f policies/host-firewall.yaml   (read its header first)
    fab-peering:  walkthrough only — see the lab / README (needs a 2nd cluster).
EOF
