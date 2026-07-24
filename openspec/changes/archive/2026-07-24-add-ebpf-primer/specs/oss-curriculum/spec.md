## ADDED Requirements

### Requirement: An eBPF concept primer precedes the notes that assume eBPF internals
The curriculum SHALL include a short eBPF concept primer positioned at or before the first note that reasons about eBPF internals (no later than the Domain 3 runtime-security note, and reachable from the earlier Domain 2 Cilium material). The primer SHALL cover, at minimum: what eBPF is, hook points (syscalls, kprobes/tracepoints, and the LSM hook), the verifier and why loaded programs are constrained to be safe, the distinction between observe-only (kprobe) and enforce-capable (LSM) attachment, and CO-RE / the modern probe. The notes that use eBPF (runtime-security's Falco/Tetragon and the Cilium material) SHALL cross-link the primer so that the external eBPF introduction is depth rather than a prerequisite.

#### Scenario: The learner understands eBPF before Falco/Tetragon
- **WHEN** a learner reaches the Domain 3 runtime-security note and its Falco/Tetragon material
- **THEN** an eBPF primer has already defined hook points, the verifier, and observe-vs-enforce, so the learner can follow the note without first reading an external eBPF introduction

#### Scenario: Tetragon's in-kernel enforcement is explicable from course material
- **WHEN** the note describes Tetragon enforcing in-kernel (kill/signal on match) versus Falco observing and alerting
- **THEN** the primer's kprobe-vs-LSM distinction makes that difference explicable without leaving the curriculum
