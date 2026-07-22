# Implement network segmentation and zero-trust connectivity

Domain 2, subsection 3 (`d2-network`). By default a Kubernetes pod can reach every other pod in the cluster — flat, unsegmented, trust-by-location. This subsection closes that: **NetworkPolicy** segments east-west traffic, a **service mesh** enforces identity-aware mTLS, secure **ingress** terminates TLS at the edge, and (walkthrough) a **perimeter firewall** guards the host/edge. Primary labs: [d2-network-policy](../../labs/d2-network-policy.md) and [d2-ingress-waf](../../labs/d2-ingress-waf.md); environment in [`lab-infra/network/`](../../lab-infra/network/).

> The **classic L3 virtual-network fabric** — VPC dataplane, NAT-gateway egress, cloud-firewall FQDN rules, flow logs, and peering — is covered hands-on in the companion subsection **`d2-fabric`** ([`network-fabric.md`](network-fabric.md)), which builds those controls on Cilium. This subsection is the Kubernetes-native (east-west) view; `d2-fabric` is the L3 fabric (north-south / egress) view.

## Segment east-west traffic with default-deny NetworkPolicies

*Objective: `net-policy` · OSS: Kubernetes NetworkPolicy ≈ SC-500: NSGs / segmentation · Lab: [d2-network-policy](../../labs/d2-network-policy.md)*

A **NetworkPolicy** is a namespaced object that whitelists pod-to-pod (and pod-to-external) traffic by label selector. The default is "all allowed"; the moment *any* policy selects a pod, that pod becomes **deny-by-default for the direction(s) named**, and only the listed rules are permitted. The zero-trust pattern is therefore: apply a **default-deny** policy per namespace, then add narrow allow rules. Policies match by `podSelector` (pods in this namespace) and `namespaceSelector` (source/dest namespaces), on ingress and/or egress.

```yaml
# default-deny-all.yaml — selects every pod, allows nothing (both directions)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: oss500-apps
spec:
  podSelector: {}                 # empty selector = every pod in the namespace
  policyTypes: [Ingress, Egress]
---
# allow-web-to-db.yaml — only pods labelled app=web may reach app=db on 5432
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-to-db
  namespace: oss500-apps
spec:
  podSelector:
    matchLabels: {app: db}
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector: {matchLabels: {app: web}}
      ports:
        - {protocol: TCP, port: 5432}
```

Enforcement is done by the **CNI plugin**, not the API server — so the CNI *must* support NetworkPolicy. kind's default `kindnet` has only recently gained NetworkPolicy support and it's limited; for reliable, complete enforcement this course installs **Calico** in `lab-infra/network/`. A policy applied under a CNI that ignores it is the classic "policy exists but traffic still flows" trap.

This is the Kubernetes analog of **Network Security Groups / micro-segmentation**. An NSG is a stateful allow/deny list on a subnet/NIC by IP/port; a NetworkPolicy is the same idea keyed on **labels** instead of IPs (pods are ephemeral, labels are stable). "Default-deny then allow" is exactly the NSG hardening SC-500 wants.

A subtle gap: a default-deny **egress** policy also blocks DNS, so pods can't resolve anything and everything "breaks" mysteriously. The standard fix is an explicit allow to `kube-dns`/CoreDNS on UDP/TCP 53:

```yaml
# allow-dns.yaml — pair with any default-deny-egress or the cluster stops resolving
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: kube-system}}
      ports:
        - {protocol: UDP, port: 53}
        - {protocol: TCP, port: 53}
```

Exam gotchas:

- NetworkPolicy is **default-allow until a policy selects the pod** — an empty `podSelector: {}` with both `policyTypes` is the canonical default-deny.
- Enforcement is the **CNI's** job. Under a non-enforcing CNI (or default kindnet) policies may be silently ignored — install Calico to actually block.
- Selectors are **label-based**, not IP-based — the segmentation follows workloads as they reschedule, unlike an IP-keyed NSG.
- Egress policies are separate from ingress; locking down egress (e.g., only DNS + the DB) is what contains a compromised pod's outbound C2. Forgetting the **DNS allow** is the #1 default-deny-egress footgun.
- NetworkPolicy is **namespaced and additive** — policies are OR'd, so you can't write a "deny" rule that overrides an allow; you restrict by *not* allowing. For richer L7/cluster-wide rules you need `AdminNetworkPolicy` or Calico's `GlobalNetworkPolicy`.

**Resources:**
- [NetworkPolicy concepts (Kubernetes)](https://kubernetes.io/docs/concepts/services-networking/network-policies/) (~20 min)
- [Calico for kind / NetworkPolicy enforcement](https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind) (~15 min)
- [Network Policy recipes (editable examples)](https://github.com/ahmetb/kubernetes-network-policy-recipes) (~20 min)
- [AdminNetworkPolicy — cluster-scoped policy API](https://network-policy-api.sigs.k8s.io/api-overview/) (~15 min)
- [NSA/CISA Kubernetes Hardening Guide — network separation](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF) (~30 min, reference)

## Enforce mTLS and identity-aware east-west controls with a service mesh

*Objective: `net-mesh` · OSS: Istio / Linkerd ≈ SC-500: Private Link / zero-trust networking · Lab: [d2-network-policy](../../labs/d2-network-policy.md)*

NetworkPolicy filters by label but doesn't *authenticate* the traffic — a pod that spoofs another's IP could still connect. A **service mesh** adds cryptographic workload identity: a sidecar proxy (Envoy for Istio, the linkerd2-proxy for Linkerd) is injected next to every pod and transparently wraps all pod-to-pod traffic in **mutual TLS**, so each side proves its identity with a short-lived certificate tied to its ServiceAccount. Linkerd does automatic mTLS out of the box; Istio enables it per-workload/namespace with a **PeerAuthentication** in `STRICT` mode, and then you write **AuthorizationPolicy** to allow only specific identities.

```yaml
# Istio: require mTLS for every workload in the namespace
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: oss500-apps
spec:
  mtls:
    mode: STRICT                 # reject any non-mTLS (plaintext) connection
---
# Only the "web" ServiceAccount may call the "db" workload — identity, not IP
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: db-allow-web
  namespace: oss500-apps
spec:
  selector:
    matchLabels: {app: db}
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/oss500-apps/sa/web"]
```

Now identity is cryptographic (the SPIFFE principal `…/sa/web`), not positional — the zero-trust ideal of "never trust the network, always verify identity." Combine with NetworkPolicy (defense in depth: L3/4 segmentation + L7 identity). Against SC-500 this covers **zero-trust networking / Private Link**: Azure Private Link keeps traffic off the public internet on a trusted backbone; a mesh goes further, making even *internal* east-west traffic authenticated and encrypted so location grants no trust.

Under the hood the mesh runs its own **certificate authority** (Istiod's `istio-ca` or Linkerd's `identity` component) that mints short-lived (hours) SVID certs to each proxy and rotates them automatically — the workload never handles key material, and a stolen cert expires fast. This is the SPIFFE/SPIRE identity model in practice. Istio's newer **ambient mode** (ztunnel + waypoint) delivers the same mTLS without a per-pod sidecar, trading some L7 features for lower overhead. This mesh CA is one of four in the course; for which CA owns which job, see the *which CA when* box in [`keys-and-certificates.md`](keys-and-certificates.md).

Exam gotchas:

- NetworkPolicy is L3/4 by **label**; a mesh is L7 by **cryptographic identity** (mTLS). Use both — segmentation *and* authentication.
- Istio `PeerAuthentication STRICT` rejects plaintext; a `PERMISSIVE` default (mesh onboarding) still accepts unencrypted traffic — a common "mTLS enabled but plaintext still works" misconfiguration.
- Mesh identity is the pod's **ServiceAccount** (SPIFFE `spiffe://cluster.local/ns/<ns>/sa/<sa>`) — this is the workload identity from Domain 1, reused for network authz.
- The sidecar must be injected (namespace/pod label `istio-injection=enabled`) for the pod to participate; un-injected pods bypass the mesh's controls — and an `AuthorizationPolicy` with an empty `rules: []` denies all, while no policy at all defaults to allow.
- mTLS here is **east-west** encryption in transit; it's a different control from encryption at rest (`data-encrypt`) — the exam tests that you don't conflate them.

**Resources:**
- [Istio mutual TLS migration / PeerAuthentication](https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/) (~20 min)
- [Istio AuthorizationPolicy task](https://istio.io/latest/docs/tasks/security/authorization/authz-http/) (~20 min)
- [Linkerd automatic mTLS](https://linkerd.io/2/features/automatic-mtls/) (~15 min)
- [SPIFFE/SPIRE — workload identity concepts](https://spiffe.io/docs/latest/spiffe-about/overview/) (~20 min)
- [Istio ambient mesh (sidecar-less mTLS)](https://istio.io/latest/docs/ambient/overview/) (~15 min)

## Secure ingress with TLS termination and authenticated access

*Objective: `net-ingress` · OSS: ingress-nginx + cert-manager ≈ SC-500: Secure ingress / App Gateway · Lab: [d2-ingress-waf](../../labs/d2-ingress-waf.md)*

North-south traffic enters the cluster through an **Ingress**. ingress-nginx terminates **TLS** at the edge using a cert from a referenced TLS Secret — and with cert-manager's `cert-manager.io/cluster-issuer` annotation, that cert is *issued and renewed automatically* (the `cert-issuer`/`cert-lifecycle` link). Beyond TLS, ingress-nginx can require **authentication** before traffic ever reaches the app: external auth via `nginx.ingress.kubernetes.io/auth-url` (pointing at oauth2-proxy → Keycloak from Domain 1), or simple `auth-basic`.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app
  namespace: oss500-apps
  annotations:
    cert-manager.io/cluster-issuer: oss500-ca          # auto-issue + renew the TLS cert
    nginx.ingress.kubernetes.io/ssl-redirect: "true"   # force HTTPS
    nginx.ingress.kubernetes.io/auth-url: "https://oauth2-proxy.oss500-apps.svc/oauth2/auth"
spec:
  ingressClassName: nginx
  tls:
    - hosts: [app.oss500.local]
      secretName: app-tls                              # cert-manager writes/renews this
  rules:
    - host: app.oss500.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: {name: app, port: {number: 80}}
```

TLS terminates at the controller; internally you pair this with the mesh (`net-mesh`) so the edge-to-app hop is also encrypted (end-to-end). This is **secure ingress / Application Gateway** on Azure: TLS termination and cert binding at the edge, forced HTTPS redirect, and pre-auth — and it's the same box that hosts the WAF in the next subsection (`waf-*`), exactly as App Gateway bundles WAF.

Exam gotchas:

- TLS **terminates** at the ingress by default — the hop from ingress to pod is plaintext unless a mesh (`net-mesh`) or backend TLS re-encrypts it.
- cert-manager + the `cluster-issuer` annotation makes cert renewal hands-off; a stale/expired ingress cert usually means a broken Issuer or unmatched namespace scope.
- `auth-url`/oauth2-proxy enforces authentication *at the edge* before the request hits the app — the ingress is the natural place to bolt on both authN and the WAF.
- `ssl-redirect`/`force-ssl-redirect` is what actually stops plaintext HTTP; TLS being configured doesn't disable port 80 on its own.

**Resources:**
- [ingress-nginx TLS & HTTPS](https://kubernetes.github.io/ingress-nginx/user-guide/tls/) (~15 min)
- [ingress-nginx external OAUTH / auth-url annotations](https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/) (~15 min)
- [cert-manager with ingress-nginx (ACME tutorial)](https://cert-manager.io/docs/tutorials/acme/nginx-ingress/) (~20 min)
- [oauth2-proxy — configuration overview](https://oauth2-proxy.github.io/oauth2-proxy/configuration/overview) (~15 min)
- [Kubernetes Gateway API — API Overview (GatewayClass/Gateway/Route resource model)](https://gateway-api.sigs.k8s.io/docs/concepts/api-overview/) (~15 min)

## Apply perimeter firewall and segmentation concepts for the host/edge — walkthrough

*Objective: `net-firewall` · OSS: OPNsense / pfSense / nftables ≈ SC-500: Azure Firewall · Lab: [d2-network-policy](../../labs/d2-network-policy.md) (walkthrough section)*

**Walkthrough** — a full network-appliance firewall (OPNsense/pfSense) wants its own NICs and network segments, impractical to run meaningfully on a single laptop host, so study the model. Where NetworkPolicy and the mesh secure *inside* the cluster (east-west), a **perimeter firewall** guards the network edge (north-south) between zones: it does **stateful** packet filtering (tracks connection state so return traffic is allowed without a mirror rule), NAT, and enforces **DMZ segmentation** — untrusted internet → DMZ (public-facing services) → trusted internal, with default-deny between zones. **OPNsense**/**pfSense** are full FreeBSD-based firewall distros; on a single Linux host, **nftables** (the successor to iptables) expresses the same stateful ruleset:

> **Hands-on counterpart:** this appliance model stays a walkthrough, but the *enforcement* it couldn't run locally — a **DNS/FQDN application allowlist** actually blocking a non-approved domain, plus host-level firewalling in eBPF — is now hands-on as **`fab-fqdn`** in the cloud-network-fabric subsection ([`network-fabric.md`](network-fabric.md), lab [d2-network-fabric](../../labs/d2-network-fabric.md)). Study `net-firewall` for the perimeter/NAT/zone model (the truest 1:1 with the Azure networking stack); build `fab-fqdn` to see FQDN rules deny a callout live.

```
# nftables: default-deny inbound, allow established + explicit services
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    ct state established,related accept        # stateful: return traffic
    iif "lo" accept
    tcp dport { 22, 443 } accept               # only SSH + HTTPS from outside
  }
}
```

This maps to **Azure Firewall**: a stateful, centralized, network-perimeter control with allow/deny rules, threat intel, and zone segmentation — distinct from an NSG (which is a distributed subnet/NIC ACL, the NetworkPolicy analog). SC-500's layering — Azure Firewall at the perimeter, NSGs for micro-segmentation — is exactly perimeter firewall (this objective) + NetworkPolicy (`net-policy`).

Exam gotchas:

- Perimeter firewall (Azure Firewall / OPNsense) = centralized, stateful, north-south edge control; NSG / NetworkPolicy = distributed east-west micro-segmentation. Don't conflate them.
- **Stateful** means return traffic for an established connection is auto-allowed — you don't write a reverse rule. A stateless ACL would need both directions.
- DMZ segmentation = default-deny between untrusted/semi-trusted/trusted zones; public services live in the DMZ so a compromise doesn't reach the internal zone.
- This is `walkthrough` — studied at depth, not run on the reference host; the cluster analog you *do* run is NetworkPolicy + mesh.

**Resources:**
- [OPNsense firewall documentation](https://docs.opnsense.org/manual/firewall.html) (~20 min)
- [nftables quick reference (netfilter.org)](https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes) (~15 min)
- [pfSense firewall fundamentals](https://docs.netgate.com/pfsense/en/latest/firewall/index.html) (~20 min)
- [nftables stateful firewall examples](https://wiki.nftables.org/wiki-nftables/index.php/Simple_ruleset_for_a_home_router) (~10 min)
- [CIS Benchmarks (host firewall hardening baselines)](https://www.cisecurity.org/cis-benchmarks) (~15 min, reference)

## Summary

| Objective | Takeaway |
|---|---|
| `net-policy` | NetworkPolicy is default-allow until a policy selects a pod; apply default-deny then narrow allows; CNI (Calico) must enforce it; label-keyed NSG analog |
| `net-mesh` | Service mesh adds mTLS + identity-aware AuthorizationPolicy (SPIFFE SA identity); Istio `PeerAuthentication STRICT`; L7 authentication atop L3/4 segmentation |
| `net-ingress` | ingress-nginx terminates TLS (auto-issued/renewed by cert-manager), forces HTTPS, and pre-authenticates via auth-url/oauth2-proxy; App Gateway analog |
| `net-firewall` | Stateful perimeter firewall (OPNsense/pfSense/nftables) for north-south edge + DMZ segmentation ≈ Azure Firewall (walkthrough) |
