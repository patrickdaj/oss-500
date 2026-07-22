# Fundamentals: containers and OCI images

Ramp notes — no exam objective maps here. The goal is enough container fluency that the supply-chain and pod-hardening material (Phase 3) lands.

## Images vs containers

An **image** is an immutable, layered filesystem plus metadata (entrypoint, env, exposed ports). A **container** is a running (or stopped) instance of an image with a writable top layer. Images are addressed by digest (`sha256:…`) and usually tagged (`nginx:1.27`). Tags are mutable pointers; **digests are not** — pinning by digest is a supply-chain control you'll meet again with cosign and admission policies.

Layers come from each build instruction and are content-addressed and cached. A secret copied into an early layer stays in the image even if a later layer deletes it — which is why secret scanning (`data-secretscan`) looks *inside image layers*, not just the final filesystem.

## Running and inspecting

- `docker run --rm -it alpine sh` — throwaway container.
- `docker build -t myapp .` — build from a `Dockerfile`.
- `docker history <image>` — see the layers and the instruction that made each.
- `docker inspect <image>` — see the config (user, entrypoint, env).

## Dockerfile hardening basics

The habits that pay off in Phase 3:

- **Run as non-root**: add a `USER` that isn't `root`. Most base images default to root — a container running as root that escapes has root on the node's namespace.
- **Minimal base**: `distroless` or `alpine` shrink the attack surface and the CVE count a scanner will find.
- **No secrets in layers**: pass secrets at runtime (env, mounted files), never `COPY` them in.
- **Read-only friendly**: write only to explicit volumes/`tmpfs` so the container can run with a read-only root filesystem.

## Why this matters for security

Every Kubernetes workload is a container. The controls you'll implement — image scanning (Trivy/Grype), signing (cosign), `securityContext` hardening, runtime detection (Falco) — all assume you understand that an image is a stack of layers running as some user with some capabilities. "Run as non-root with a read-only root filesystem and no extra capabilities" is the single most repeated hardening instruction in this course.

## Self-check

1. What's the difference between tagging an image `:latest` and pinning it by digest, and why does the digest matter for supply-chain security?
2. If a build `COPY`s a private key and a later instruction `RUN rm`s it, is the key still recoverable from the image? Why?
3. Name two `Dockerfile` changes that reduce what a runtime scanner or attacker can exploit.

## Primary sources
- [Docker documentation](https://docs.docker.com/) (reference) · [Get started — Introduction](https://docs.docker.com/get-started/introduction/)
- [Open Container Initiative (OCI) — image & runtime specs](https://opencontainers.org/) (reference)
- [Kubernetes — Container images](https://kubernetes.io/docs/concepts/containers/images/)
