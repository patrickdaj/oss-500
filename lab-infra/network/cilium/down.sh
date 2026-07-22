#!/usr/bin/env bash
# Tear down the cloud-network-fabric controls and Cilium.
# Note: Cilium is the CNI, so uninstalling it leaves the cluster without a dataplane —
# the clean reset is `kind delete cluster --name oss500`. This script removes the
# fabric policies + demo workloads and (optionally) the Cilium release.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Removing fabric policies (egress gateway, FQDN, host firewall if applied)"
kubectl delete -f "$here/policies/" --ignore-not-found || true

echo "==> Removing fabric demo workloads"
kubectl delete -f "$here/manifests/clients.yaml" --ignore-not-found || true

echo "==> Unlabeling the egress gateway node"
kubectl label node oss500-worker egress-gateway- --overwrite 2>/dev/null || true

echo "==> Fabric controls removed."
echo "    To also remove Cilium (leaves the cluster with NO CNI):"
echo "      helm uninstall cilium -n kube-system"
echo "    Cleanest full reset:  kind delete cluster --name oss500"
