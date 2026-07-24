## Why

The curriculum provisions its cluster with `kind` and teaches Kubernetes as something you *operate and secure* — correctly, since no SC-500 objective is "bootstrap a control plane." But that convenience hides the cluster's trust model: the Phase-0 note (`domains/0-fundamentals/02-kubernetes.md`) names the control-plane components conceptually, yet the learner never sees that **every component authenticates to every other with a certificate off the cluster CA**, that the **kubelet is a network-reachable, attackable API** (10250, anonymous-auth), or that **Falco/Tetragon hook the CRI/containerd boundary** they later instrument. For this persona — a senior network/firewall engineer strong on PKI and data paths but new to Kubernetes — that internals gap is exactly where his existing strength should be doing the most work, and it's where real cluster attack surface lives (kubelet, etcd-at-rest, CNI-vs-NetworkPolicy). Building a cluster from scratch (kubeadm/containerd/Calico, à la *Kubernetes The Hard Way*) is the usual way people meet these internals, but that's a cluster-admin/CKA skill tree, off-mission and costly for a lab-heavy security course.

## What Changes

- Add a short **cluster-internals security primer** — "how the cluster is wired, and where it's soft" — that reuses the persona's PKI/networking strength to walk the control-plane trust model as *attack surface*: the cluster CA / PKI mesh between components, the API server as the single front door, **etcd** (all state, unencrypted at rest by default), the **kubelet** as a reachable API (10250, anonymous-auth, the `authorization-mode` webhook), the **CRI/containerd** boundary where runtime enforcement hooks, and the **CNI** as the seam where NetworkPolicy is (or isn't) enforced. Positioned in/adjacent to Phase-0 `02-kubernetes.md` and cross-linked from the notes that assume these internals (RBAC, runtime-security, net-policy, data-encrypt).
- Explicitly frame this as a **security lens on `kind`, not a from-scratch build**: the primer states that the course keeps `kind`, and points to *Kubernetes The Hard Way* as **optional depth** for anyone who wants the full kubeadm/containerd/CNI bootstrap — so the door is open without putting cluster-bootstrap on the critical path.
- Add an **optional, explicitly non-tracked enrichment lab** — "attack the kubelet" — that probes the kubelet API on the existing `kind` cluster, observes that authn/authz is enforced (401/403, webhook authz), inspects the flags that make it so (`--anonymous-auth=false`, `--authorization-mode=Webhook`), and connects the CRI boundary to what Falco/Tetragon observe in Domain 3. It follows the standard lab format with a concrete observable, and is marked enrichment (no `tracker.yaml` objective), like walkthrough labs are marked.
- No new tracked objective and no `tracker.yaml` change; external links satisfy `resource-citation`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `oss-curriculum`: adds a requirement that a cluster-internals *security* primer precede/accompany the notes that reason about the control-plane trust model, teaching the CA/PKI mesh, API server, etcd-at-rest, kubelet, CRI, and CNI as attack surface on the existing `kind` cluster — with *Kubernetes The Hard Way* named as optional depth rather than a required build step.
- `hands-on-labs`: adds a requirement recognizing an **optional enrichment lab** category — a standard-format lab with a concrete verification that is explicitly *not* mapped to a tracker objective — and mandates the "kubelet attack surface" lab as its first instance, so the catalog-coverage requirement is not read as forbidding non-tracked enrichment labs.

## Impact

- Affected specs: `oss-curriculum` (one ADDED requirement), `hands-on-labs` (one ADDED requirement).
- Affected content (at implementation time): a primer section in (or adjacent to) `domains/0-fundamentals/02-kubernetes.md`; cross-links from `domains/1-identity-governance/kubernetes-rbac.md`, `domains/3-compute-ai/runtime-security.md`, `domains/2-secrets-data-networking/*` (net-policy, data-encrypt); a new `labs/enrichment-kubelet-attack-surface.md` (or similar) and a catalog-index note marking it optional/enrichment.
- Slots beside `add-k8s-manifest-authoring-onramp` (authoring) and `add-ebpf-primer` (the CRI/eBPF substrate the kubelet lab points at); no `tracker.yaml`, `readiness.md`, or checkpoint changes.
- Turns the "cluster internals are invisible under `kind`" gap from a silent prerequisite into standalone course material, without adding a cluster-bootstrap track.
