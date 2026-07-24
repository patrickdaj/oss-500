# Fundamentals: eBPF — hook points, the verifier, and observe vs enforce

Ramp notes — no exam objective maps here. [`network-fabric.md`](../2-secrets-data-networking/network-fabric.md) has Cilium implement the entire CNI dataplane "in eBPF (programs attached in-kernel) rather than iptables," and [`runtime-security.md`](../3-compute-ai/runtime-security.md) has Falco tap the syscall stream via "a modern eBPF probe" and has Tetragon attach a `TracingPolicy`'s kprobes/LSM hooks that can `Sigkill` a process synchronously in-kernel — both assume you already know what a hook point, a verifier, and CO-RE are. This note doesn't: what eBPF actually is, where a program attaches (syscalls, kprobes/tracepoints, the LSM hook), why the verifier lets you load code into a running kernel without a crash-the-box risk, why kprobe-vs-LSM is an observe-vs-enforce distinction and not a syntax choice, and what CO-RE buys the modern probe over the legacy kernel-module driver — so `network-fabric.md`'s dataplane and `runtime-security.md`'s Falco/Tetragon material read as familiar mechanics, not an unexplained black box offloaded to an external site. Read this before [`network-fabric.md`](../2-secrets-data-networking/network-fabric.md) (`fab-cni`) and no later than [`runtime-security.md`](../3-compute-ai/runtime-security.md) (`rt-falco`/`rt-tetragon`).

## What eBPF actually is

**eBPF** (extended Berkeley Packet Filter — the name outlived the original packet-filter use case) lets you run small, sandboxed programs *inside the running kernel*, attached to events the kernel already fires, without writing a kernel module, compiling against that kernel's headers, or rebooting. A program is compiled to BPF bytecode, loaded from userspace via the `bpf()` syscall, checked by the kernel (the verifier, below), and then executed in-kernel whenever its hook fires. Programs cannot reach arbitrary kernel memory or call arbitrary kernel functions — the only way they exchange state with userspace or persist data across invocations is a **BPF map** (a key/value store the kernel and a userspace process can both read and write: a counter, an allow-list, a ring buffer of events). That constraint is the whole difference from a kernel module: a module is arbitrary compiled code the kernel simply trusts; an eBPF program is restricted code the kernel *checked* before it was allowed to run.

## Hook points — where a program attaches

- **Syscalls.** A program can attach to the raw enter/exit of any syscall (`sys_enter_execve`, `sys_enter_connect`). This is Falco's classic path: tap the syscall stream and evaluate every event against a rule.
- **kprobes / kretprobes.** Dynamic instrumentation: attach to the entry or return of almost any kernel function, at runtime, with no kernel rebuild. Tetragon's `TracingPolicy` names a kernel function directly in its `kprobes:` block (`call: "security_file_permission"`) — that's a kprobe on a specific function.
- **Tracepoints.** Static, kernel-maintainer-defined instrumentation points baked into a subsystem (scheduler, block I/O, network). Unlike a kprobe, which hooks a function's actual signature and breaks if that signature changes across kernel versions, a tracepoint is a stable, versioned contract the kernel maintainers commit to keeping.
- **The LSM hook.** The Linux Security Module framework's sanctioned security-decision points — functions like `security_file_permission` or `security_bprm_check` that the kernel calls specifically to ask "is this action allowed?" These are the same points SELinux and AppArmor hook; `BPF_PROG_TYPE_LSM` makes them programmable in eBPF.

Notice `security_file_permission` can be reached two ways — a kprobe on it, or the real LSM hook — and that distinction is the one the next section turns on.

## The verifier — why loading kernel-resident code doesn't risk a crash

Before a program is attached to any hook, the kernel's **verifier** statically walks every possible path through it and rejects anything it can't prove safe: control flow must provably terminate (a loop the verifier can't bound is rejected at load time, not left to run and hang the kernel), every pointer dereference is checked against a known-valid range (a map value, a packet buffer, a specific context field — no arbitrary memory access), and the program is capped on instruction count and stack size with no unbounded recursion. A program that fails any of these checks never runs at all — load fails with a verifier error, the kernel is never at risk. That single property is what makes "attach code that looks arbitrary to a security-critical kernel function" a tractable thing to allow by default: the kernel checked the program before it ran, instead of trusting whoever wrote it.

## kprobe vs LSM: observe vs enforce

A kprobe reads arguments and can emit an event the moment a kernel function runs, but its return value doesn't change what that function does next — it's instrumentation bolted alongside the real code path, not part of the decision. The LSM hook is structurally different: it exists *because* the kernel is asking a yes/no security question at that exact point, and a `BPF_PROG_TYPE_LSM` program's return value **is the answer** — returning deny stops the action synchronously, in the same call, before it completes. That is exactly the line `runtime-security.md` draws between Falco (evaluates the syscall/kprobe stream in userspace — can only alert *after* the action already happened) and Tetragon's `Sigkill`/`Override` `matchActions` (only reliably un-bypassable when they hook an LSM point: a kprobe attached to one specific syscall can be sidestepped by a different syscall that reaches the same kernel effect, while the LSM hook is the sanctioned choke point every path funnels through).

## CO-RE and the modern probe

Historically, an eBPF program had to be compiled against the exact target kernel's headers, because kernel data-structure layouts (struct field offsets) shift across versions and build configs — a program compiled for one kernel could read the wrong offset on another. **CO-RE** (Compile Once – Run Everywhere) removes that coupling: the compiler emits relocatable field-access instructions alongside **BTF** (BPF Type Format — compact type/debug metadata describing the *running* kernel's actual struct layouts), and a small loader patches the compiled bytecode's offsets against that kernel's BTF at load time. One compiled binary now runs unmodified across kernel versions and configs. This is precisely `runtime-security.md`'s "prefer the modern eBPF probe over the legacy kernel module" guidance: the legacy driver needs headers matched to that exact node's kernel and can silently fail to load on one it wasn't built for, leaving that node uninstrumented; a CO-RE/BTF probe just runs.

## Putting it together

| Concept | What it answers | Where D2/D3 build on it |
|---|---|---|
| eBPF program + BPF maps | in-kernel code, verified before it runs, state shared only via maps | `fab-cni` — Cilium's whole dataplane is eBPF programs and maps instead of iptables |
| Syscall hook | tap the raw syscall stream | `rt-falco` — Falco's kernel-module/eBPF-probe driver taps syscalls |
| kprobe / kretprobe | instrument any kernel function's entry/return, no rebuild | `rt-tetragon` — a `TracingPolicy`'s `kprobes:` block naming e.g. `security_file_permission` |
| Tracepoint | stable, maintainer-defined instrumentation point | background: why a tracepoint doesn't break across kernel versions the way a raw kprobe can |
| LSM hook (`BPF_PROG_TYPE_LSM`) | the kernel's real security-decision point — return value blocks the action | `rt-tetragon` — why `Sigkill`/`Override` should hook an LSM point, not a bare kprobe |
| Verifier | proves a program can't crash or hang the kernel, before it is ever loaded | why "attach arbitrary-looking code to the kernel" is safe to allow at all |
| CO-RE + BTF | one compiled probe runs unmodified across kernel versions | `rt-falco`'s "prefer the modern eBPF probe" exam gotcha |

## Self-check

1. A program you try to load has a loop the kernel can't prove terminates. What rejects it, and does that happen at load time or at runtime?
2. A `TracingPolicy` needs to actually kill a process the instant it opens `/etc/shadow`, not just log the attempt. Should its `kprobes:` entry hook a raw syscall, a kprobe on a `security_*` function, or the LSM hook on that same function — and why is only one of the three genuinely un-bypassable?
3. Falco's DaemonSet silently stops reporting events on exactly one node in the cluster. What's the likely driver-related cause, and which probe type — legacy or modern — avoids it?
4. What does BTF give a CO-RE-compiled eBPF program that a program compiled against one kernel's headers doesn't have?

## Primary sources
- [Linux kernel docs — BPF Verifier](https://docs.kernel.org/bpf/verifier.html) `[depth]` (~15 min)
- [Linux kernel docs — Kprobe-based Event Tracing](https://docs.kernel.org/trace/kprobes.html) `[depth]` (~10 min)
- [Linux kernel docs — BPF LSM](https://docs.kernel.org/bpf/prog_lsm.html) `[depth]` (~15 min)
- [Andrii Nakryiko — BPF CO-RE Reference Guide](https://nakryiko.com/posts/bpf-core-reference-guide/) `[depth]` (~20 min)
- [eBPF.io — What is eBPF?](https://ebpf.io/what-is-ebpf/) (reference) — broader introduction and ecosystem tour beyond what this primer covers
