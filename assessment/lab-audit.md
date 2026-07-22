# Lab & Plan Self-Containment Audit

**Date:** 2026-07-22 · **Branch:** `fix/lab-audit-followups`

> **Status:** all findings below fixed on this branch (41 files changed) and
> statically verified — no stale `-p oss500`, no false SPIRE-reuse claims, no
> unconditional `kind create cluster` in prereqs, and `bash -n` clean on all
> touched scripts. Not yet runtime-tested on a live cluster (see the two items
> under *Needs live-cluster verification*).

## Why this audit

A learner following the fundamentals ramp got stuck: they were told to deploy
Kubernetes workloads before being told to create the cluster, and the only
concrete walkthrough on offer (the kubernetes.io *Basics* tutorial) provisions
with **minikube** — tooling this course never uses (OSS-500 is kind-only).

That prompted a full pass over every phase plan and lab guide against one
standard: **is each self-contained, are prerequisites front-loaded, and does
anything send you to an external/optional source that leaves you stuck?**

## Rubric

1. **Self-contained happy path** — runnable start-to-finish without bouncing to an external source that assumes different tooling.
2. **Prerequisites front-loaded** — the cluster / `up.sh` / prior-lab dependency is stated up top, in the right order — not assumed mid-stream.
3. **No load-bearing "optional" detours** — no minikube/non-kind assumptions; no external link marked optional that's actually required.
4. **Complete loop** — Goal → Setup → Walkthrough-with-verification → Teardown.
5. **No unstated cross-lab / cross-phase dependencies.**

## Headline

Of ~42 files audited: **~20 clean, ~17 minor, 5 need a real revisit.** The course
is fundamentally solid — every lab has the full deploy→verify→destroy loop, and
there are **no minikube assumptions in the labs**. One root cause (no canonical
"the Phase 0 cluster is already up" contract) explains the original stuck plus
about a third of all findings.

## Root cause — the cluster bootstrap contract

There was no single, referenced statement that the `oss500` kind cluster is
created once in Phase 0 and reused everywhere. Consequences, all fixed together:

- The ramp deployed workloads (Day 2) before creating the cluster (Day 3).
- Some labs ran an **unconditional** `kind create cluster`, which *errors*
  (`cluster already exists`) against the reused cluster.
- Other labs silently *assumed* the cluster and the `oss500-apps` namespace.

**Canonical prereq wording now used across labs:**

> The shared **Phase 0 kind cluster** is up (reused by every lab) — check with
> `kind get clusters` (you should see `oss500`). If it isn't, create it once:
> `kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml`
> then `lab-infra/shared/up.sh`.

## 🔴 Blockers — got a learner stuck

- [x] **Phase 0 Day 2 deploys before Day 3 builds the cluster.** `plan/phase0-fundamentals.md` — move cluster creation to the start of Day 2.
- [x] **Fundamentals note points at minikube.** `domains/0-fundamentals/02-kubernetes.md` — annotate the kubernetes.io tutorial as concepts-only; add kind-native deploy/expose/scale commands.
- [x] **Keycloak SSO/MFA lab fails on its first command.** `labs/d1-keycloak-sso-mfa.md` — `$KEYCLOAK_ADMIN_PASSWORD` is only sourced inside `identity/up.sh`'s subshell; add an explicit `source lab-infra/identity/admin-password.env` prereq step.
- [x] **Conditional-access lab inherits the same failure.** `labs/d1-keycloak-conditional-access.md`.
- [x] **NetworkPolicy lab's prereqs are false.** `labs/d2-network-policy.md` — `network/up.sh` installs neither Calico nor Istio (kindnet enforces basic policy; Calico is optional/manual; Istio is `up-mesh.sh`), and `up.sh` already pre-applies the policies, so the "everything talks" baseline is wrong.

## 🟠 Systemic — cluster bootstrap contract

- [x] `labs/d1-kubernetes-rbac.md`, `labs/d1-workload-identity.md` — replace unconditional `kind create cluster` with the canonical check-then-create wording.
- [x] `labs/d2-network-fabric.md` — legitimately rebuilds the cluster with a Cilium config; add an explicit `kind delete cluster --name oss500` first.
- [x] `labs/d2-cert-manager.md`, `d2-data-protection.md`, `d2-ingress-waf.md`, `d2-vault-k8s-injection.md` — add the cluster + `lab-infra/shared` prereq line (they deploy into `oss500-apps` but never state it).
- [x] `labs/d3-pod-security.md`, `labs/d4-observability.md` — rated clean by the audit, but aligned to the canonical check-then-create prereq wording so every lab states the contract identically.

## 🟡 Notable friction

- [x] **`labs/d5-infra-attack-simulation.md`** — runs Falco/Tetragon + Suricata + Wazuh simultaneously with no RAM note (contradicts the "run alone" rule → OOM risk); references a `throwaway` pod it never creates.
- [x] **Compose project collision** — `lab-infra/network-detection` and `lab-infra/siem` both used `-p oss500`, so one stack's `down.sh -v` could nuke the other's volumes. Renamed to `-p oss500-netdet` and `-p oss500-siem`; referencing labs updated.
- [x] **Phase 5 attacks unbuilt ZTNA brokers.** `plan/phase5` depends on `d1-ztna-*` brokers that `plan/phase1` never schedules — the labs/infra exist, so Phase 1 now schedules them.
- [x] **Phase 6 "reused SPIRE server" is wrong — SPIRE is deployed *nowhere*.** `identity/up.sh` is Keycloak-only; `d1-workload-identity` covers SPIFFE/SPIRE as a *walkthrough*; `agentic/up.sh` never deploys or checks it. Reconciled across `plan/phase6`, `plan/overview`, and the `lab-infra/agentic/` files (README, up.sh, down.sh, spire/registration.md): SPIRE registration is now framed as **directions** against a server you stand up yourself; only the Keycloak realm is genuinely reused.
- [x] **`labs/d2-ingress-waf.md`** — depends on the `oss500-ca-issuer` hand-built in `d2-cert-manager`, not shipped by `certs/up.sh`. Reworded.
- [x] **`labs/d3-ai-security.md`** — authenticated path needs a Keycloak token; identity component added to prereqs.
- [x] **`labs/d3-runtime-detection.md`** — no eBPF/Docker-Desktop-macOS caveat; added (matches `lab-infra/README.md`).
- [x] **`labs/d1-ztna-netbird.md`** — core infra hid behind an unlinked external compose quickstart; link pinned and framed as an external dependency.
- [x] **`labs/d1-ztna-boundary.md`** — "private SSH host" prereq had no setup; added a throwaway-container one-liner.

## 🟢 Polish

- [x] `labs/d1-ztna-pomerium.md` — circular OIDC-client prereq removed; `internal-app` create command added.
- [x] `plan/phase2-secrets-data-networking.md` — Calico wording reconciled (kindnet enforces basic policy; Calico optional).
- [x] `labs/d2-data-protection.md` — note that etcd `docker exec` assumes the `oss500-control-plane` node name.

## Needs live-cluster verification (not blocking)

- Kyverno-vs-PodSecurityAdmission message ordering in `d1-governance-policy.md` Part A.
- The `d2-network-policy.md` baseline step, once the pre-applied-policies reframe lands.

## Clean (no changes)

Phase plans: `overview`, `phase3`, `phase4`, `review`. Fundamentals notes:
`00-linux-cli`, `01-containers`, `03-kind-helm-iac`, `04-linux-networking`,
`05-git-iac-foundation`. Labs: `d1-governance-policy`, `d1-privileged-access`,
`d1-ztna-openziti`, `d2-vault-dynamic-secrets`, `d3-supply-chain`,
`d4-network-detection`, `d4-siem-wazuh`, `d4-vuln-posture`, `d5-ai-redteam`,
`d5-ztna-authz`, and all `d6-*`.
