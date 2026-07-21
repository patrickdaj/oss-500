# network — segmentation, service mesh, and a WAF ingress

Three composable network controls for Domain 2. Backs the labs
[d2-network-policy](../../labs/d2-network-policy.md) (policies + mesh) and
[d2-ingress-waf](../../labs/d2-ingress-waf.md) (TLS ingress + WAF).
**SC-500 correspondence:** NSG segmentation + Private Link/zero-trust networking +
App Gateway WAF + secure ingress. (The host/edge perimeter-firewall objective
`net-firewall` is a **walkthrough** in the network-policy lab.)

**Objectives:** `net-policy`, `net-mesh`, `net-ingress`, `waf-deploy`, `waf-rules`, `waf-verify`

**Footprint:**
- Policies + demo app + ingress-nginx WAF ≈ 300–400 MB.
- Istio (`up-mesh.sh`) adds ~400–600 MB — **run the mesh part alone.**

Bring up only what the current lab step needs.

```bash
./up.sh          # NetworkPolicies (default-deny) + ingress-nginx WAF + demo app
./up-mesh.sh     # (separate/heavier) Istio + STRICT mTLS + authorization policy
```

> **CNI note:** kind's default kindnet enforces basic NetworkPolicy, but for
> reliable egress and `namespaceSelector` behaviour install Calico first (command
> printed by `up.sh`).

**Verify**
```bash
# net-policy: allowed path works, non-allowed path times out
kubectl -n oss500-apps exec client -- curl -s --max-time 4 http://web:8080 && echo OK
kubectl -n oss500-apps delete -f policies/allow-client-to-web.yaml
kubectl -n oss500-apps exec client -- curl -s --max-time 4 http://web:8080 || echo "DENIED (timeout)"

# net-ingress: TLS terminated by ingress-nginx with a cert-manager cert
curl -k --resolve demo.localtest.me:8443:127.0.0.1 https://demo.localtest.me:8443/ -I

# waf-verify: a SQLi payload is blocked with HTTP 403
curl -k --resolve demo.localtest.me:8443:127.0.0.1 \
  "https://demo.localtest.me:8443/?id=1%27%20OR%20%271%27=%271" -o /dev/null -w "%{http_code}\n"
kubectl -n ingress-nginx logs deploy/ingress-nginx-controller | grep -i ModSecurity | tail

# net-mesh: STRICT mTLS in force
istioctl x describe pod "$(kubectl -n oss500-apps get pod -l app=web -o name | head -1 | cut -d/ -f2)" -n oss500-apps
```

**Teardown**
```bash
./down.sh        # policies + ingress + demo app, and calls down-mesh.sh
```
