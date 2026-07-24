## Why

The course reasons about eBPF internals before any note explains eBPF. `domains/3-compute-ai/runtime-security.md` leans on hook points, the syscall stream, kmod-vs-eBPF drivers, CO-RE, and in-kernel enforcement (Tetragon) as if known, and Domain 2's Cilium material assumes the same substrate earlier still (audit P8). The persona's networking depth softens this — he understands kernel data paths — but "hook point," "verifier," and "kprobe vs LSM" are never defined, so the load-bearing `eBPF.io — What is eBPF?` link is silently mandatory and the note under-teaches the one concept its whole runtime-detection story rests on.

## What Changes

- Add a short **eBPF concept primer** at the point eBPF is first assumed (no later than D3 `runtime-security`; ideally reachable from the earlier D2 Cilium mention): what eBPF is, hook points (syscalls/kprobes/tracepoints/LSM), the verifier and why programs are safe to load, kprobe vs LSM (observe vs enforce), and CO-RE / the modern probe — enough that a learner can read the Falco/Tetragon and Cilium material without leaving the note.
- Cross-link the primer from `runtime-security.md` (and the D2 Cilium mention) so the `eBPF.io` reference becomes depth, not a prerequisite.
- No new tracked objective and no `tracker.yaml` change; external links satisfy the `resource-citation` standard.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `oss-curriculum`: adds a requirement that an eBPF concept primer precede the first note that reasons about eBPF internals, so runtime-security (Falco/Tetragon) and Cilium teach standalone rather than offloading the load-bearing concept to an external link.

## Impact

- Affected specs: `oss-curriculum` (one ADDED requirement).
- Affected content (at implementation time): a primer section (in a Phase-0 fundamentals note or as a preamble at eBPF's first use) plus cross-links from `domains/3-compute-ai/runtime-security.md` and the Domain 2 Cilium mention.
- Turns P8 from "intermediate + reference-dependent" toward "standalone."
