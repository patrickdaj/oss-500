## Context

OSS-500 runs on a single `kind` cluster and teaches Kubernetes as something you operate and secure. The Phase-0 note (`domains/0-fundamentals/02-kubernetes.md`) already names the control-plane/node components and calls out two internals-level facts (etcd Secrets are unencrypted at rest; pods are unsegmented by default). What it does not do is present the cluster's *trust model* — the CA/PKI mesh, the kubelet as a reachable API, the CRI boundary — as attack surface the learner can reason about. The persona is a senior network/firewall engineer with deep PKI and data-path intuition, so this is the cheapest possible depth to add: it reuses knowledge he already has.

The constraint that shapes this change: **`kind` is deliberately hardened.** A kind node's kubelet already runs with `--anonymous-auth=false` and `--authorization-mode=Webhook`, and there is no read-only port (10255). So a naive "attack the kubelet" lab that expects to dump pod lists from an unauthenticated 10250 will simply get 401/403 — which is the *correct* posture, not a failure. The lab has to be designed around that reality rather than fighting it.

## Goals / Non-Goals

**Goals:**
- Give the learner a security-lens mental model of cluster internals (CA/PKI mesh → API server → etcd; kubelet API; CRI/containerd; CNI) anchored to the existing `kind` cluster.
- Make the kubelet concrete: probe it, observe enforcement, tie the observed behavior to specific flags, and connect the CRI boundary forward to Domain 3 runtime security.
- Keep cluster bootstrap *available* (link *Kubernetes The Hard Way*) without putting it on the critical path.

**Non-Goals:**
- No from-scratch / kubeadm / containerd / Calico build track. `kind` stays the one cluster.
- No new `lab-infra/` insecure-kubelet variant that reconfigures the cluster to enable anonymous auth (see Decision 2).
- No new tracked objective, no `tracker.yaml`/`readiness.md`/checkpoint change.

## Decisions

**Decision 1 — Primer lives in the Phase-0 note, not a new file.** Extend `domains/0-fundamentals/02-kubernetes.md` with a "How the cluster is wired (and where it's soft)" section rather than creating a standalone note. Rationale: the note already opens the control-plane/node model and the etcd-at-rest fact; the primer is its natural deepening, and keeping it inline means the cross-links from RBAC/runtime/net-policy point at one canonical place. Alternative considered: a separate `domains/0-fundamentals/03-cluster-internals.md`. Rejected as over-fragmenting Phase-0 ramp material for ~1 screen of content.

**Decision 2 — The kubelet lab demonstrates a *closed* attack surface, with the open case shown read-only.** The lab probes `kind`'s kubelet on 10250 from inside the cluster and observes 401/403, then inspects the running kubelet config (`/var/lib/kubelet/config.yaml` / process flags) to show *why* it's closed (`anonymous-auth: false`, `authorization.mode: Webhook`). The dangerous contrast — what an `anonymous-auth: true` kubelet leaks (`/pods`, `/exec`, `/runningpods`) — is presented as annotated output/reading, **not** by reconfiguring the shared cluster. Rationale: enabling anonymous auth on the one cluster every other lab depends on is a foot-gun (it would make the cluster genuinely exploitable for the session, and risk a learner leaving it that way). Alternative considered: a throwaway second kind cluster with an insecure `kubeletExtraArgs` patch. Rejected for this change as scope creep into `lab-infrastructure` (a new cluster variant, footprint, teardown guarantees) for marginal gain over annotated output; it can be a follow-up if demand exists.

**Decision 3 — The lab is an *enrichment* lab, exempt from objective coverage.** Rather than inventing a tracker objective (which would ripple into `tracker.yaml`, checkpoints, and the readiness gate), the change adds an explicit "optional enrichment" lab category to `hands-on-labs` and marks the lab as such in `labs/README.md`. Rationale: this is depth beyond the SC-500 skills outline, not coverage of it; the coverage requirement should not be read as forbidding optional depth. Alternative considered: fold the exercise into the primer note with no lab. Rejected because a runnable probe-and-observe loop is exactly what makes the kubelet real for this persona.

**Decision 4 — Point forward, don't duplicate.** The primer's CRI/containerd and CNI paragraphs cross-link the existing `add-ebpf-primer` (eBPF substrate) and the Cilium/NetworkPolicy material rather than re-explaining them. *Kubernetes The Hard Way* is cited once as optional depth.

## Risks / Trade-offs

- [Learner expects a "real" kubelet exploit and finds it locked down] → Frame the closed posture as the lesson ("this is what right looks like, and here's exactly what an open one leaks"); the annotated open-case output carries the offensive payload conceptually.
- [`kind`/kubelet flag paths or defaults drift across versions] → Have the lab *read* the live config (`kubectl get --raw` / node config file) rather than asserting a fixed value, so verification reflects the actual cluster; note the kind version the lab was validated against.
- [Scope creep toward a from-scratch track] → The proposal and spec both state `kind` stays; *Kubernetes The Hard Way* is explicitly optional depth, not a step.
- [Cross-links rot as notes are renamed] → Use existing relative-link conventions and let `npm run lint:links` gate the change.

## Migration Plan

Additive documentation-and-lab change; no deploy or rollback surface. Implementation order: (1) primer section in `02-kubernetes.md`; (2) cross-links from RBAC/runtime/net-policy/data-encrypt notes; (3) `labs/enrichment-kubelet-attack-surface.md` in standard format; (4) mark it optional in `labs/README.md`; (5) link check + `openspec validate`. Rollback is deletion of the added section, lab, and links.

## Open Questions

- Final filename/slug for the lab (`labs/enrichment-kubelet-attack-surface.md` proposed) and how `labs/README.md` visually marks the enrichment category (new column value vs. separate table) — resolve against the current catalog layout at implementation time.
