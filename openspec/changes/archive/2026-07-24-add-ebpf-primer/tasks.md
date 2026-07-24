## 1. Write the eBPF primer

- [x] 1.1 Add a short eBPF concept primer at the point eBPF is first assumed (a Phase-0 fundamentals note or a preamble at D3 `runtime-security`'s eBPF section), covering: what eBPF is, hook points (syscalls/kprobes/tracepoints/LSM), the verifier, kprobe-vs-LSM (observe vs enforce), and CO-RE / the modern probe.
- [x] 1.2 Cross-link the primer from `domains/3-compute-ai/runtime-security.md` and from the Domain 2 Cilium mention, and re-mark the `eBPF.io — What is eBPF?` link as depth `(reference)` rather than an implicit prerequisite.
- [x] 1.3 Ensure new external links satisfy `resource-citation` and `npm run lint:links` passes; confirm no `tracker.yaml`/objective change.

## 2. Validation

- [x] 2.1 Run `openspec validate add-ebpf-primer --type change --strict` and confirm it passes.
