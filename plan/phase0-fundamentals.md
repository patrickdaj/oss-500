# Phase 0 — Fundamentals ramp

Build the platform fluency the security curriculum assumes: Linux/CLI, containers and OCI images, Kubernetes primitives, Helm, and the `kind` + IaC loop. This is a **ramp, not the security content** — no checkpoint gates it. Skip only the days whose self-checks you can already pass cold.

Set up the reference host and the cluster once here; every later phase reuses it. Prerequisites to install: Docker, [kind](https://kind.sigs.k8s.io/), `kubectl`, [Helm](https://helm.sh/), and `git`.

## Day 1 — Linux, shell, and containers

- [ ] **[2h] Linux/CLI refresher** — users/groups/UIDs, file permissions, processes, namespaces + capabilities, systemd basics, `journalctl`, networking (`ss`, `ip`, `curl`, `dig`). Notes: [domains/0-fundamentals/00-linux-cli.md](../domains/0-fundamentals/00-linux-cli.md). You'll read a lot of container and pod logs this course.
- [ ] **[2h] Containers and OCI images** — images vs containers, layers, `docker run`/`build`, registries, `Dockerfile` hardening basics (non-root `USER`, minimal base). Notes: [domains/0-fundamentals/01-containers.md](../domains/0-fundamentals/01-containers.md). Concept anchor for supply-chain security later.
- [ ] **[1.5h] Build and inspect an image** — write a tiny Dockerfile, build it, `docker history`, run it as non-root, see it fail to write to a read-only path.
- [ ] **[1h] Notes review** — finish both fundamentals notes above; be able to explain "a container is just a process," "rootless," and "read-only root filesystem."

## Day 2 — Kubernetes primitives

- [ ] **[0.5h] Stand up the kind cluster (do this first)** — you need a running cluster before you can deploy anything today. Create it once and reuse it for the whole course:
  ```bash
  kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml
  lab-infra/shared/up.sh
  ```
  That's a 1 control-plane + 2 worker cluster; `up.sh` also creates the shared namespaces (including `oss500-apps`) and installs ingress-nginx. This is the single cluster every later phase reuses.
- [ ] **[2h] Kubernetes model** — control plane vs nodes, the API server, declarative objects, `kubectl get/describe/apply`, namespaces, labels/selectors. Today's note — [domains/0-fundamentals/02-kubernetes.md](../domains/0-fundamentals/02-kubernetes.md) — backs all of Day 2 (model, workload objects, and the token model); read it alongside these blocks.
- [ ] **[2h] Workload objects** — Pods, Deployments, ReplicaSets, Services, ConfigMaps, Secrets (and why a base64 Secret is *not* encrypted). Deploy nginx, expose it, scale it.
- [ ] **[1.5h] ServiceAccounts and the token model** — every pod gets a ServiceAccount; projected tokens; this is the seed of workload identity (Phase 1).
- [ ] **[1h] Consolidate + self-check** — finish [02-kubernetes.md](../domains/0-fundamentals/02-kubernetes.md) and answer its self-check: why a base64 Secret isn't encrypted, and where a pod's identity comes from.

## Day 3 — kind cluster, Helm, and the IaC loop

- [ ] **[0.5h] git + Terraform foundation** — read [domains/0-fundamentals/05-git-iac-foundation.md](../domains/0-fundamentals/05-git-iac-foundation.md) *first*: the git snapshot model (working tree/index/repo, branches, remotes, GitOps) and Terraform's write→plan→apply loop with state + locking. It's the foundation under today's applied kind/Helm work, and every later lab is Terraform-automated — get the plumbing straight before it's in your way.
- [ ] **[2h] Know your lab cluster** — you already created the `oss500` cluster on Day 2, and `up.sh` installed the ingress controller and the shared namespaces/labels. Read [lab-infra/README.md](../lab-infra/README.md) to understand what that bootstrap did (ingress, namespaces including `oss500-apps`), confirm the cluster is up (`kind get clusters` shows `oss500`), and inspect it (`kubectl get ns`, `kubectl get pods -A`). Today's note — [domains/0-fundamentals/03-kind-helm-iac.md](../domains/0-fundamentals/03-kind-helm-iac.md) — backs all of Day 3 (kind, Helm, and the deploy→verify→destroy loop); read it alongside these blocks.
- [ ] **[2h] Helm** — charts, values, releases, `helm install/upgrade/template`, and why `helm template` makes IaC reviewable. Install one chart (e.g. a demo app) and read its rendered manifests.
- [ ] **[1.5h] The deploy → verify → destroy loop** — practice the discipline every lab uses: `up.sh` a component, check it's healthy, `down.sh` it, confirm no leftovers (`kubectl get all -A`, `docker ps`).
- [ ] **[1h] Consolidate + self-check** — finish [03-kind-helm-iac.md](../domains/0-fundamentals/03-kind-helm-iac.md); prove you can install and uninstall a Helm chart with nothing left behind.

## Day 4 — RBAC preview and flex

- [ ] **[1.5h] Kubernetes RBAC preview** — Roles, ClusterRoles, bindings, `kubectl auth can-i`. Just enough to be comfortable; Phase 1's [kubernetes-rbac.md](../domains/1-identity-governance/kubernetes-rbac.md) goes deep.
- [ ] **[1.5h] YAML/manifest fluency** — reading `securityContext`, resource limits, and probes in a manifest without flinching.
- [ ] **[1h] Catch-up / rest** — finish any self-checks; make sure `kind`, `kubectl`, and `helm` all work end to end before Phase 1.

> **Read-ahead (no study block yet).** [`domains/0-fundamentals/04-linux-networking.md`](../domains/0-fundamentals/04-linux-networking.md) is the Linux-networking substrate — network namespaces, veth pairs, CIDR, routing, NAT — that the segmentation and cloud-fabric labs stand on. It lives in Phase 0 but is **deep-read in Phase 2 at point of use**, alongside [`network-fabric.md`](../domains/2-secrets-data-networking/network-fabric.md) and the [`d2-network-fabric`](../labs/d2-network-fabric.md) lab, so it adds no Phase 0 hours here.

## Self-check (pass before Phase 1)

1. Create a namespace, deploy a non-root pod with a read-only root filesystem, and confirm it can't write to `/`.
2. Explain why a Kubernetes `Secret` is only base64-encoded and what would make it encrypted at rest.
3. Install and uninstall a Helm chart and prove nothing is left behind.
4. Use `kubectl auth can-i` to check whether a ServiceAccount can list secrets in a namespace.
5. Explain the difference between the git working tree, staging area (index), and repository — and describe what Terraform **state** records and why a shared backend must **lock** it during an apply.
