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

- The shared **Phase 0 kind cluster** is up (reused by every lab) — check with `kind get clusters` (you should see `oss500`). If it isn't, create it once: `kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml` then `lab-infra/shared/up.sh`.
- [`lab-infra/network`](../lab-infra/network/) up (`./up.sh`) for **Part A** — deploys the demo app (`web` + a `client` pod) and the baseline NetworkPolicies (`default-deny-all` + `allow-dns` + `allow-client-to-web`). It does **not** install a new CNI: kind's built-in `kindnet` already enforces the basic NetworkPolicy this part uses. (Calico is only needed for advanced egress/`namespaceSelector` behaviour and is an *optional* manual step — `kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml`.)
- For **Part B** (the service mesh), run `./up-mesh.sh` — Istio is a separate, heavier install and is **not** part of `up.sh`.
- Notes read: [network-security.md](../domains/2-secrets-data-networking/network-security.md).
- Tools for this lab: `istioctl` (mesh install/inspect) — install per [`../TOOLS.md`](../TOOLS.md).

**Estimated time**: 2–3 h · $0 (local)

> **CNI note:** NetworkPolicy is only *enforced* if the CNI implements it. kind's built-in `kindnet` **does** enforce the basic ingress/egress policies Part A uses — so default-deny actually denies out of the box, no extra CNI required. Where `kindnet` stops short is advanced behaviour (some `namespaceSelector`/egress edge cases); for that you can *optionally* install **Calico** by hand (`kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml`). The classic "my NetworkPolicy did nothing" gotcha is a CNI that ignores policy entirely — kindnet isn't one.

## Challenge

**Part A — segmentation (`net-policy`).** `up.sh` already brings `oss500-apps` up as a **default-deny** namespace with exactly one east-west path opened — `client → web`, via the shipped `allow-client-to-web` policy. Prove the default-deny is doing the real work by *deleting* that one allow and watching the path go dark, then restore it — and understand how you'd author the same least-privilege segmentation from scratch, so every other client stays denied.
- Observable: `curl http://web:8080` from `client` **succeeds** while `allow-client-to-web` is in place, **times out** the moment you delete it (it falls back to the namespace-wide `default-deny-all`), then **succeeds again** once the targeted allow is re-applied.

**Part B — identity-aware mesh (`net-mesh`).** Layer a service mesh over the segmented namespace so authorization is based on cryptographic workload identity, not IP/label, and every hop is encrypted.
- Observable: a call carrying the allowed SPIFFE principal returns **200**; a call from any other identity gets Envoy's **"RBAC: access denied"**; `istioctl x describe` reports **`mTLS: STRICT`** for the workload.

**Part C — perimeter firewall (`net-firewall`) *(walkthrough)*.** Reason through how a perimeter firewall governs north-south traffic at the network edge — complementary to, not a substitute for, the east-west controls in Parts A/B. Impractical to run fully on a laptop; studied at the same depth.

No solutions below — design and write the policies yourself, prove each observable, then check your work against the Reference solution.

## Build it (guided)

### Part A — Default-deny then targeted allow (`net-policy`)

1. **See what `up.sh` already shipped.** The `network` component does *not* leave `oss500-apps` wide open — it deploys the `web` app plus a `client` pod and *three* NetworkPolicies: `default-deny-all` (ingress **and** egress), `allow-dns`, and `allow-client-to-web`. So the namespace already starts as a default-deny zone with exactly one east-west path opened. Inspect them before you touch anything:
   ```bash
   kubectl -n oss500-apps get networkpolicy
   kubectl -n oss500-apps get pods -l app.kubernetes.io/part-of=oss500
   ```
2. **Baseline — one *allowed* path, not "everything talks."** Because `default-deny-all` is already enforced, the only reason `client` can reach `web` is the shipped `allow-client-to-web` policy. Confirm that single path works:
   ```bash
   kubectl -n oss500-apps exec client -- curl -s --max-time 4 http://web:8080    # -> nginx welcome HTML (allowed)
   ```
3. **Prove the default-deny is really doing the work.** Delete the one targeted allow and predict what happens to the call above — with `allow-client-to-web` gone, `client` falls back to the namespace-wide `default-deny-all`:
   ```bash
   kubectl delete -f lab-infra/network/policies/allow-client-to-web.yaml
   kubectl -n oss500-apps exec client -- curl -s --max-time 4 http://web:8080
   # curl: (28) Operation timed out        <- dropped, not refused: the control is working
   ```
4. **Restore the path — your turn.** Re-open exactly the `client → web` path and nothing else. You *can* just re-apply the shipped policy, but the real exercise is to **author it yourself**: write a `NetworkPolicy` that allows ingress to `app=web` only from pods labelled `app=client` on TCP 8080, apply it, and confirm the call succeeds again.
   - Hint: the ingress policy's `podSelector` targets `app: web`; the allowed source goes in an `ingress[].from[].podSelector` matching `app: client`; scope `ports` to TCP 8080. Because `default-deny-all` also denies *egress*, the `client` pod additionally needs a matching egress allow toward `app: web` (this is what the shipped `allow-client-to-web.yaml` bundles as a companion policy).
   ```bash
   kubectl -n oss500-apps exec client -- curl -s --max-time 4 http://web:8080    # -> nginx HTML again (allowed)
   ```
5. **Prove least-privilege — your turn.** A path is only least-privilege if the *wrong* identity stays out. Run the same `curl` from a pod that is **not** labelled `app=client` (relabel a throwaway pod, or stand up a second client with a different label) and confirm it still **times out** — your allow rule keys on the pod label, so only `client` gets through.
6. **The additive model.** NetworkPolicies are **additive** — `default-deny-all` sets the baseline, each allow rule punches one scoped hole. (Cross-namespace scenarios use `namespaceSelector`; the shipped `allow-dns` is itself an egress exception — study it, then try locking egress down to DNS + the DB only.)

### Part B — Identity-aware east-west with a service mesh (`net-mesh`)

NetworkPolicy filters by label/IP; a **service mesh** adds cryptographic **workload identity** and **mTLS** — the zero-trust "encrypt and authenticate every hop, authorize by service identity not IP" model (the Private Link / zero-trust analogue).

7. **Open the management-plane path first — the shipped fix.** Part A left `oss500-apps` under namespace-wide default-deny *egress* too. An injected Envoy sidecar has its own control-plane traffic — xDS config and certificate issuance from **istiod on `15012`** — and default-deny blocks that just like anything else: sidecars come up `2/2` but never get a workload cert, so STRICT mTLS (next step) fails silently for everyone. `up-mesh.sh` applies `lab-infra/network/policies/allow-egress-to-istiod.yaml` before enabling injection — an egress allow scoped to `namespaceSelector: istio-system` on TCP `15012`, nothing else. This is defense-in-depth working as intended: the L4 control **and** the mesh identity control both stay in force; you just have to open the one path the mesh's own machinery needs.
   ```bash
   kubectl -n oss500-apps get networkpolicy allow-egress-to-istiod   # shipped by up-mesh.sh
   ```
8. Label a namespace for Istio sidecar injection and deploy two services (or reuse `oss500-apps` with injection enabled by the component):
   ```bash
   kubectl label namespace oss500-apps istio-injection=enabled --overwrite
   kubectl -n oss500-apps rollout restart deploy    # pods come back with an Envoy sidecar (2/2)
   ```
9. **Enforce STRICT mTLS — your turn.** Goal: reject plaintext mesh-wide; every call must present a mesh-issued SPIFFE identity cert.
   - Hint: a `PeerAuthentication` named `default` in the namespace, with `spec.mtls.mode: STRICT`.
   - Your turn: write `strict-mtls.yaml` and apply it.
   - If sidecars stay uncertified and STRICT mTLS fails for every workload, re-check step 7 first — a missing istiod egress path is the classic cause, not a bad `PeerAuthentication`.
10. **Add identity-based authorization — your turn.** Goal: default-deny the namespace via `AuthorizationPolicy`, then allow exactly one identity — authorization by *service account principal*, not IP.
    - Hint: an empty-spec `AuthorizationPolicy` selecting the workload denies everything for it; the companion allow policy scopes `selector.matchLabels.app: web`, sets `action: ALLOW`, and restricts `rules[].from[].source.principals` to a single principal, `cluster.local/ns/oss500-apps/sa/client` — the `client` pod's own ServiceAccount (shipped in `demo-app.yaml`).
    - Your turn: write both policies (e.g. `deny-all` + `allow-client`) and apply them.
11. **Prove it**:
    - A call from the `client` workload → **200**.
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

- **Before/after segmentation**: with the shipped `allow-client-to-web` in place, `curl http://web:8080` from `client` **succeeds**; delete that one policy and the same call **times out** (it falls back to `default-deny-all`); re-apply it and the call **succeeds again**. The observable is a single request that goes from allowed → dropped → re-allowed by toggling exactly one policy — while a pod without the `app: client` label stays denied throughout.
- **Mesh**: a call carrying the allowed SPIFFE principal returns 200; a call from any other identity returns Envoy's "RBAC: access denied"; `istioctl x describe` reports `mTLS: STRICT` — proving identity- and encryption-based east-west control beyond IP filtering.

## Reference solution

Build it yourself first; check after.

### Part A — NetworkPolicy (`net-policy`)

The `network` component ships these already (`up.sh` applies them); the point of the exercise is to be able to author them yourself. A **default-deny** policy for the namespace — an empty `podSelector` selects every pod, and with no `ingress`/`egress` rules, all east-west traffic is dropped in both directions:
```yaml
# default-deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny-all, namespace: oss500-apps, labels: { app.kubernetes.io/part-of: oss500 } }
spec:
  podSelector: {}                        # net-policy: selects ALL pods in the namespace
  policyTypes: ["Ingress", "Egress"]     # no rules below => deny all inbound AND outbound
```

Re-open **exactly one path**: allow ingress to `app=web` only from pods labelled `app=client`, plus the companion egress the client needs under default-deny egress:
```yaml
# allow-client-to-web.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-client-to-web, namespace: oss500-apps, labels: { app.kubernetes.io/part-of: oss500 } }
spec:
  podSelector: { matchLabels: { app: web } }        # target: the web pods
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector: { matchLabels: { app: client } }   # net-policy: only client may reach it
      ports:
        - { protocol: TCP, port: 8080 }
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-client-egress-to-web, namespace: oss500-apps, labels: { app.kubernetes.io/part-of: oss500 } }
spec:
  podSelector: { matchLabels: { app: client } }     # the client's egress side
  policyTypes: ["Egress"]
  egress:
    - to:
        - podSelector: { matchLabels: { app: web } }
      ports:
        - { protocol: TCP, port: 8080 }
```
```bash
kubectl apply -f lab-infra/network/policies/allow-client-to-web.yaml   # or your own equivalent
```
(Because `default-deny-all` also denies egress, the shipped `allow-dns` policy — egress to `k8s-app: kube-dns` on 53 — is what still lets pods resolve the `web` Service name; the component ships it alongside the two above.)

### Part B — service mesh mTLS + authorization (`net-mesh`)

Enforce **STRICT mTLS** — plaintext is now rejected mesh-wide; every call must present a mesh-issued SPIFFE identity cert:
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

Add a **default-deny AuthorizationPolicy**, then allow one identity — authorization by *service account principal*, not IP:
```yaml
# authz.yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata: { name: deny-all, namespace: oss500-apps }
spec: {}                         # empty spec = deny-all in the namespace
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata: { name: allow-client, namespace: oss500-apps }
spec:
  selector: { matchLabels: { app: web } }
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/oss500-apps/sa/client"]   # identity-aware allow: the client pod's own SA
```
```bash
kubectl apply -f authz.yaml
```

If your "default-deny" NetworkPolicy leaves an `ingress` key present (even empty) instead of omitting it, double-check behavior against your CNI — the absence of the ingress rules list is what denies all. If the AuthorizationPolicy allow rule checks `namespaces` instead of `principals`, any pod in the namespace bypasses the identity check — key the allow on the SPIFFE principal, not location.

## Teardown

- `cd lab-infra/network && ./down.sh`

> **Validate it *(purple team)*.** Prove the default-deny actually segments: run an in-cluster scan (**ATT&CK T1046**) from a pod that shouldn't reach the DB in [`d5-infra-attack-simulation`](d5-infra-attack-simulation.md) and confirm it times out — then confirm the ZTNA brokers deny lateral reach in [`d5-ztna-authz`](d5-ztna-authz.md).

## What the exam asks

- Kubernetes is **allow-all by default** — there is *no* segmentation until a NetworkPolicy exists, and policies are **enforced only by a CNI that supports them**. kind's built-in `kindnet` covers the basic ingress/egress case; Calico/Cilium add advanced selectors. "My policy didn't block anything" → check the CNI (a CNI that ignores policy outright is the classic culprit).
- **Default-deny + explicit allow** is the pattern (empty `podSelector`, no rules = deny; then additive allow rules). Denied traffic **times out** (silently dropped), it isn't refused — a diagnostic tell.
- `podSelector` vs `namespaceSelector` vs `ipBlock`, and `Ingress` vs `Egress` `policyTypes` — know which selects the *target* pods vs the *allowed sources*.
- **NetworkPolicy filters by label/IP; a service mesh authorizes by cryptographic workload identity and encrypts with mTLS.** Zero-trust "authenticate and authorize every service-to-service call regardless of network position" = mesh, the OSS mirror of Private Link + identity-based access.
- **Layers are complementary**: perimeter firewall (north-south edge) + NetworkPolicy/NSG (segment) + mesh mTLS (identity) — a question asking to "encrypt and authenticate east-west traffic" is the mesh; "restrict which pods can reach the DB" is NetworkPolicy; "block inbound from the internet except 443" is the perimeter firewall.
