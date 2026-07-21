# Phase 0 — Fundamentals ramp

Build the platform fluency the security curriculum assumes: Linux/CLI, containers and OCI images, Kubernetes primitives, Helm, and the `kind` + IaC loop. This is a **ramp, not the security content** — no checkpoint gates it. Skip only the days whose self-checks you can already pass cold.

Set up the reference host and the cluster once here; every later phase reuses it. Prerequisites to install: Docker, [kind](https://kind.sigs.k8s.io/), `kubectl`, [Helm](https://helm.sh/), and `git`.

## Day 1 — Linux, shell, and containers

- [ ] **[2h] Linux/CLI refresher** — users/groups/UIDs, file permissions, processes, namespaces + capabilities, systemd basics, `journalctl`, networking (`ss`, `ip`, `curl`, `dig`). Notes: [domains/0-fundamentals/00-linux-cli.md](../domains/0-fundamentals/00-linux-cli.md). You'll read a lot of container and pod logs this course.
- [ ] **[2h] Containers and OCI images** — images vs containers, layers, `docker run`/`build`, registries, `Dockerfile` hardening basics (non-root `USER`, minimal base). Notes: [domains/0-fundamentals/01-containers.md](../domains/0-fundamentals/01-containers.md). Concept anchor for supply-chain security later.
- [ ] **[1.5h] Build and inspect an image** — write a tiny Dockerfile, build it, `docker history`, run it as non-root, see it fail to write to a read-only path.
- [ ] **[1h] Notes review** — finish both fundamentals notes above; be able to explain "a container is just a process," "rootless," and "read-only root filesystem."

## Day 2 — Kubernetes primitives

- [ ] **[2h] Kubernetes model** — control plane vs nodes, the API server, declarative objects, `kubectl get/describe/apply`, namespaces, labels/selectors.
- [ ] **[2h] Workload objects** — Pods, Deployments, ReplicaSets, Services, ConfigMaps, Secrets (and why a base64 Secret is *not* encrypted). Deploy nginx, expose it, scale it.
- [ ] **[1.5h] ServiceAccounts and the token model** — every pod gets a ServiceAccount; projected tokens; this is the seed of workload identity (Phase 1).
- [ ] **[1h] Notes** — [domains/0-fundamentals/02-kubernetes.md](../domains/0-fundamentals/02-kubernetes.md).

## Day 3 — kind cluster, Helm, and the IaC loop

- [ ] **[2h] Stand up the lab cluster** — follow [lab-infra/README.md](../lab-infra/README.md): create the kind cluster, install the ingress controller, apply the shared namespaces/labels. This cluster is your lab environment for the whole course.
- [ ] **[2h] Helm** — charts, values, releases, `helm install/upgrade/template`, and why `helm template` makes IaC reviewable. Install one chart (e.g. a demo app) and read its rendered manifests.
- [ ] **[1.5h] The deploy → verify → destroy loop** — practice the discipline every lab uses: `up.sh` a component, check it's healthy, `down.sh` it, confirm no leftovers (`kubectl get all -A`, `docker ps`).
- [ ] **[1h] Notes + self-check** — [domains/0-fundamentals/03-kind-helm-iac.md](../domains/0-fundamentals/03-kind-helm-iac.md).

## Day 4 — RBAC preview and flex

- [ ] **[1.5h] Kubernetes RBAC preview** — Roles, ClusterRoles, bindings, `kubectl auth can-i`. Just enough to be comfortable; Phase 1 goes deep.
- [ ] **[1.5h] YAML/manifest fluency** — reading `securityContext`, resource limits, and probes in a manifest without flinching.
- [ ] **[1h] Catch-up / rest** — finish any self-checks; make sure `kind`, `kubectl`, and `helm` all work end to end before Phase 1.

## Self-check (pass before Phase 1)

1. Create a namespace, deploy a non-root pod with a read-only root filesystem, and confirm it can't write to `/`.
2. Explain why a Kubernetes `Secret` is only base64-encoded and what would make it encrypted at rest.
3. Install and uninstall a Helm chart and prove nothing is left behind.
4. Use `kubectl auth can-i` to check whether a ServiceAccount can list secrets in a namespace.
