#!/usr/bin/env bash
# net-mesh: install Istio (minimal profile), enable sidecar injection in
# oss500-apps, and apply STRICT mTLS + identity-aware authorization.
# Heavier than the rest of the stack — bring it up alone for the mesh part of
# the d2-network-policy lab, then ./down-mesh.sh.
# SC-500 correspondence: Private Link / zero-trust east-west networking.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-apps

if ! command -v istioctl >/dev/null 2>&1; then
  echo "istioctl not found. Install it:"
  echo "  curl -L https://istio.io/downloadIstio | sh - && export PATH=\$PWD/istio-*/bin:\$PATH"
  exit 1
fi

echo "==> Installing Istio (minimal profile)  [net-mesh]"
istioctl install --set profile=minimal -y

echo "==> Allowing egress to istiod under default-deny  [net-mesh]"
# net-mesh: oss500-apps runs namespace-wide default-deny egress (net-policy).
# Without this exception the injected sidecar can never reach istiod on 15012
# for xDS/cert issuance, so it never gets a workload cert and STRICT mTLS fails
# for everything. This opens only the management-plane L4 path.
kubectl apply -f "$here/policies/allow-egress-to-istiod.yaml"

echo "==> Enabling automatic sidecar injection in $NS  [net-mesh]"
# net-mesh: the label makes Istio inject an Envoy sidecar into every new pod so
# it can broker mTLS and enforce AuthorizationPolicy.
kubectl label namespace "$NS" istio-injection=enabled --overwrite
# Restart workloads so they pick up the sidecar.
kubectl -n "$NS" rollout restart deploy/web 2>/dev/null || true
kubectl -n "$NS" delete pod client --ignore-not-found
kubectl apply -f "$here/demo-app.yaml"

echo "==> Applying STRICT mTLS + authorization  [net-mesh]"
kubectl apply -f "$here/mesh/peerauthentication.yaml"
kubectl apply -f "$here/mesh/authorizationpolicy.yaml"

cat <<'EOF'

==> Mesh up.
    net-mesh (mTLS):  istioctl x describe pod <web-pod> -n oss500-apps  -> "STRICT"
    net-mesh (authz): client SA is allowed to reach web:8080; a pod with a
                      different ServiceAccount gets RBAC: access denied (403).
EOF
