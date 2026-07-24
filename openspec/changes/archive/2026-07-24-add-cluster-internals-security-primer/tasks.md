## 1. Write the cluster-internals security primer

- [x] 1.1 Add a "How the cluster is wired (and where it's soft)" section to `domains/0-fundamentals/02-kubernetes.md` covering the CA/PKI mesh (cluster CA as root of component trust), the API server as the single authenticated front door, etcd (all state, unencrypted at rest by default), the kubelet as a reachable API (10250, `--anonymous-auth`, `--authorization-mode`), the CRI/containerd boundary (where Falco/Tetragon hook), and the CNI as the NetworkPolicy-enforcement seam.
- [x] 1.2 Frame it explicitly as a security lens on the existing `kind` cluster: state the course keeps `kind`, and cite *Kubernetes The Hard Way* once as optional depth for the full kubeadm/containerd/CNI bootstrap (not a required step).
- [x] 1.3 Add a self-check question or two on the trust model (e.g. "why is the cluster CA the highest-value secret?", "what does an `anonymous-auth: true` kubelet expose?").

## 2. Cross-link the notes that assume these internals

- [x] 2.1 Link the primer from `domains/1-identity-governance/kubernetes-rbac.md` (component/kubelet authn), `domains/3-compute-ai/runtime-security.md` (CRI boundary; also cross-link `add-ebpf-primer`), the Domain 2 NetworkPolicy note (CNI enforcement seam), and the etcd/data-at-rest encryption material — so each reads standalone.
- [x] 2.2 Confirm no `assessment/data/tracker.yaml` objective is added or changed.

## 3. Write the optional kubelet attack-surface enrichment lab

- [x] 3.1 Create `labs/enrichment-kubelet-attack-surface.md` in the standard lab format (objectives, prerequisites, estimated time, steps, verification, teardown), running against the existing `kind` cluster with no new `lab-infra/` component.
- [x] 3.2 Steps: probe the kubelet API on 10250 from in-cluster and observe 401/403; read the live kubelet config (`kubectl get --raw` / node config file) to show `anonymous-auth: false` and `authorization.mode: Webhook`; present, as annotated read-only output (NOT by reconfiguring the cluster), what an `anonymous-auth: true` kubelet leaks (`/pods`, `/runningpods`, `/exec`); connect the CRI boundary forward to Falco/Tetragon.
- [x] 3.3 Verification: a concrete observable — unauthenticated kubelet request returns 401/403 — contrasted with the flags that enforce it. Teardown leaves no residual resources on the shared cluster. Note the kind version validated against.
- [x] 3.4 Mark the lab as an optional **enrichment** lab (not mapped to a tracker objective), visually distinct from tracked hands-on and walkthrough labs, in `labs/README.md`.

## 4. Validation

- [x] 4.1 Run `npm run lint:links` (or the repo's link check) and confirm all new external/internal links pass.
- [x] 4.2 Run `openspec validate add-cluster-internals-security-primer --type change --strict` and confirm it passes.
