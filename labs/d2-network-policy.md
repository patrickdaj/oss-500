# Lab d2: Default-deny segmentation & mesh mTLS

Watch one pod reach another, cut it off with a default-deny NetworkPolicy, then re-open exactly one path — and layer identity-aware mTLS on top with a service mesh.

**Objectives covered**

| id | Objective |
|---|---|
| `net-policy` | Segment east-west traffic with default-deny NetworkPolicies |
| `net-mesh` | Enforce mTLS and identity-aware east-west controls with a service mesh |
| `net-firewall` | Apply perimeter firewall and segmentation concepts for the host/edge *(walkthrough)* |

**SC-500 correspondence**: NSGs / network segmentation (NetworkPolicy) · Private Link / zero-trust networking (service mesh mTLS) · Azure Firewall (perimeter)

**Prerequisites**

- [`lab-infra/network`](../lab-infra/network/) up (`./up.sh`) — installs **Calico** as the CNI (kind's default `kindnet` does *not* enforce NetworkPolicy) and, for Part B, Istio.
- Notes read: [network-security.md](../domains/2-secrets-data-networking/network-security.md).

**Estimated time**: 2–3 h · $0 (local)

> **CNI note:** NetworkPolicy is only *enforced* if the CNI implements it. kind's built-in `kindnet` ignores policies (they apply but nothing blocks). The `network` component installs **Calico** so default-deny actually denies — the single most common "my NetworkPolicy did nothing" gotcha.

## Steps

### Part A — Default-deny then targeted allow (`net-policy`)

1. Deploy a server and two clients in `oss500-apps`:
   ```bash
   kubectl -n oss500-apps run web --image=nginx:1.27 --labels="app=web,app.kubernetes.io/part-of=oss500" --port=80
   kubectl -n oss500-apps expose pod web --port=80
   kubectl -n oss500-apps run client-allowed --image=busybox:1.36 --labels="role=frontend,app.kubernetes.io/part-of=oss500" --command -- sleep 3600
   kubectl -n oss500-apps run client-denied  --image=busybox:1.36 --labels="role=other,app.kubernetes.io/part-of=oss500" --command -- sleep 3600
   ```
2. **Baseline — everything talks** (Kubernetes is allow-all by default; no segmentation until you add policy):
   ```bash
   kubectl -n oss500-apps exec client-allowed -- wget -qO- --timeout=3 http://web    # -> nginx welcome HTML
   kubectl -n oss500-apps exec client-denied  -- wget -qO- --timeout=3 http://web    # -> also works (!)
   ```
3. Apply a **default-deny ingress** policy for the namespace — an empty `podSelector` selects every pod, and with no `ingress` rules, all inbound east-west traffic is dropped:
   ```yaml
   # deny-all.yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata: { name: default-deny-ingress, namespace: oss500-apps, labels: { app.kubernetes.io/part-of: oss500 } }
   spec:
     podSelector: {}                 # net-policy: selects ALL pods in the namespace
     policyTypes: ["Ingress"]        # no ingress rules below => deny all inbound
   ```
   ```bash
   kubectl apply -f deny-all.yaml
   ```
4. **Prove it's cut off** — the request now hangs and **times out** (dropped, not refused):
   ```bash
   kubectl -n oss500-apps exec client-allowed -- wget -qO- --timeout=3 http://web
   # wget: download timed out        <- the control is working
   ```
5. Re-open **exactly one path**: allow ingress to `app=web` only from pods labelled `role=frontend`:
   ```yaml
   # allow-frontend.yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata: { name: allow-frontend-to-web, namespace: oss500-apps, labels: { app.kubernetes.io/part-of: oss500 } }
   spec:
     podSelector: { matchLabels: { app: web } }        # target: the web pod
     policyTypes: ["Ingress"]
     ingress:
       - from:
           - podSelector: { matchLabels: { role: frontend } }   # net-policy: only frontend may reach it
         ports:
           - { protocol: TCP, port: 80 }
   ```
   ```bash
   kubectl apply -f allow-frontend.yaml
   ```
6. **Prove least-privilege segmentation** — only the intended client gets through; the other is still denied:
   ```bash
   kubectl -n oss500-apps exec client-allowed -- wget -qO- --timeout=3 http://web   # -> nginx HTML  (allowed)
   kubectl -n oss500-apps exec client-denied  -- wget -qO- --timeout=3 http://web   # -> times out   (denied)
   ```
   NetworkPolicies are **additive** — the deny-all sets the baseline, the allow rule punches one hole. (Cross-namespace scenarios use `namespaceSelector`; egress control uses `policyTypes: ["Egress"]` with an `egress` block — try locking egress to DNS + the DB only.)

### Part B — Identity-aware east-west with a service mesh (`net-mesh`)

NetworkPolicy filters by label/IP; a **service mesh** adds cryptographic **workload identity** and **mTLS** — the zero-trust "encrypt and authenticate every hop, authorize by service identity not IP" model (the Private Link / zero-trust analogue).

7. Label a namespace for Istio sidecar injection and deploy two services (or reuse `oss500-apps` with injection enabled by the component):
   ```bash
   kubectl label namespace oss500-apps istio-injection=enabled --overwrite
   kubectl -n oss500-apps rollout restart deploy    # pods come back with an Envoy sidecar (2/2)
   ```
8. Enforce **STRICT mTLS** — plaintext is now rejected mesh-wide; every call must present a mesh-issued SPIFFE identity cert:
   ```yaml
   # strict-mtls.yaml
   apiVersion: security.istio.io/v1
   kind: PeerAuthentication
   metadata: { name: default, namespace: oss500-apps }
   spec:
     mtls: { mode: STRICT }        # net-mesh: reject non-mTLS traffic
   ```
   ```bash
   kubectl apply -f strict-mtls.yaml
   ```
9. Add a **default-deny AuthorizationPolicy**, then allow one identity — authorization by *service account principal*, not IP:
   ```yaml
   # authz.yaml
   apiVersion: security.istio.io/v1
   kind: AuthorizationPolicy
   metadata: { name: deny-all, namespace: oss500-apps }
   spec: {}                         # empty spec = deny-all in the namespace
   ---
   apiVersion: security.istio.io/v1
   kind: AuthorizationPolicy
   metadata: { name: allow-frontend, namespace: oss500-apps }
   spec:
     selector: { matchLabels: { app: web } }
     action: ALLOW
     rules:
       - from:
           - source:
               principals: ["cluster.local/ns/oss500-apps/sa/frontend-sa"]   # identity-aware allow
   ```
   ```bash
   kubectl apply -f authz.yaml
   ```
10. **Prove it**:
    - A call from the `frontend-sa` workload → **200**.
    - A call from any other identity → **RBAC: access denied** (Envoy 403), even from inside the namespace.
    - Confirm traffic is actually mutually authenticated/encrypted:
      ```bash
      istioctl x describe pod <web-pod> -n oss500-apps      # shows "mTLS: STRICT" for the workload
      ```
    Plaintext to the pod (bypassing the sidecar) is rejected; identity — not network location — decides access.

### Part C — Perimeter firewall & host/edge segmentation (`net-firewall`) — walkthrough

*Impractical to run fully on the laptop (needs a separate firewall appliance / multiple L2 segments), but studied at the same depth — this is the Azure Firewall / NSG-at-the-edge analogue.*

11. **Concept**: NetworkPolicy and the mesh are *east-west inside the cluster*; a perimeter firewall (OPNsense/pfSense, or `nftables` on a gateway host) governs **north-south** at the network edge — the cluster/VNet boundary. Zones: untrusted WAN → DMZ (public ingress) → trusted app tier → restricted data tier.
12. **Stateful rules** (nftables sketch): default-drop, allow established/related, allow only required inbound ports to the DMZ, deny DMZ→trusted except specific flows:
    ```nft
    table inet filter {
      chain input {
        type filter hook input priority 0; policy drop;
        ct state established,related accept
        iif "lo" accept
        tcp dport { 443 } accept          # public ingress only
      }
      chain forward {
        type filter hook forward priority 0; policy drop;
        ct state established,related accept
        ip saddr 10.0.1.0/24 ip daddr 10.0.2.0/24 tcp dport 5432 accept   # app -> db only
      }
    }
    ```
13. **Mapping**: OPNsense zones/aliases ≈ Azure Firewall rule collections + NSGs; a DMZ ≈ a subnet with restrictive NSGs + a firewall in front; SNAT/DNAT ≈ Azure Firewall NAT rules. The exam theme is **defense in depth**: perimeter firewall (edge) + NSG/NetworkPolicy (segment) + mesh mTLS (identity) are complementary layers, not substitutes.

## Verification

- **Before/after segmentation**: `wget http://web` from `client-allowed` **succeeds** with no policy, **times out** after `default-deny-ingress`, then **succeeds again** once `allow-frontend-to-web` is applied — while `client-denied` still times out. The observable is a request that goes from working → dropped → selectively re-allowed.
- **Mesh**: a call carrying the allowed SPIFFE principal returns 200; a call from any other identity returns Envoy's "RBAC: access denied"; `istioctl x describe` reports `mTLS: STRICT` — proving identity- and encryption-based east-west control beyond IP filtering.

## Teardown

- `cd lab-infra/network && ./down.sh`

## What the exam asks

- Kubernetes is **allow-all by default** — there is *no* segmentation until a NetworkPolicy exists, and policies are **enforced only by a CNI that supports them** (Calico/Cilium, not vanilla kindnet). "My policy didn't block anything" → check the CNI.
- **Default-deny + explicit allow** is the pattern (empty `podSelector`, no rules = deny; then additive allow rules). Denied traffic **times out** (silently dropped), it isn't refused — a diagnostic tell.
- `podSelector` vs `namespaceSelector` vs `ipBlock`, and `Ingress` vs `Egress` `policyTypes` — know which selects the *target* pods vs the *allowed sources*.
- **NetworkPolicy filters by label/IP; a service mesh authorizes by cryptographic workload identity and encrypts with mTLS.** Zero-trust "authenticate and authorize every service-to-service call regardless of network position" = mesh, the OSS mirror of Private Link + identity-based access.
- **Layers are complementary**: perimeter firewall (north-south edge) + NetworkPolicy/NSG (segment) + mesh mTLS (identity) — a question asking to "encrypt and authenticate east-west traffic" is the mesh; "restrict which pods can reach the DB" is NetworkPolicy; "block inbound from the internet except 443" is the perimeter firewall.
