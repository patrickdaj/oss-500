#!/usr/bin/env bash
# Bring up the OSS-500 network stack: default-deny NetworkPolicies + ingress-nginx
# with a ModSecurity/OWASP-CRS WAF + the demo web app.
# The service mesh is a separate, heavier install — see up-mesh.sh.
# SC-500 correspondence: NSG segmentation + App Gateway WAF + secure ingress.
# Objectives: net-policy net-ingress waf-deploy waf-rules
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS=oss500-apps

echo "==> NOTE: NetworkPolicy enforcement needs a CNI that implements it."
echo "    kind's default kindnet enforces basic NetworkPolicy; for reliable"
echo "    egress + namespaceSelector behaviour install Calico:"
echo "    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml"

echo "==> Deploying the demo web app + client into $NS  [net-ingress]"
kubectl apply -f "$here/demo-app.yaml"

echo "==> Installing ingress-nginx with the ModSecurity WAF  [waf-deploy waf-rules]"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
helm repo update >/dev/null
# Replaces the static kind ingress from shared/up.sh with a WAF-enabled controller.
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f "$here/ingress-values.yaml" \
  --wait --timeout 5m

echo "==> Waiting for the ingress controller"
kubectl -n ingress-nginx wait --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller --timeout=180s

echo "==> Applying NetworkPolicies (default-deny + DNS + client->web)  [net-policy]"
kubectl apply -f "$here/policies/default-deny.yaml"
kubectl apply -f "$here/policies/allow-dns.yaml"
kubectl apply -f "$here/policies/allow-client-to-web.yaml"

cat <<'EOF'

==> Network stack up.
    net-policy:  kubectl -n oss500-apps exec client -- curl -s --max-time 4 http://web:8080  (allowed)
                 delete allow-client-to-web.yaml and retry -> times out (denied)
    net-ingress/waf: curl -k https://demo.localtest.me:8443/ resolves via localhost
                 (add '127.0.0.1 demo.localtest.me' to /etc/hosts, or use --resolve)
    mesh:        ./up-mesh.sh   (installs Istio; heavier — run alone)
EOF
