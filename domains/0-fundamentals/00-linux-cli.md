# Fundamentals: Linux and the shell

Ramp notes — no exam objective maps here. Enough Linux to be fluent in the primitives every security control in this course is built on. A container is just a Linux process with namespaces and cgroups around it; pod hardening, runtime detection, and secrets all reduce to Linux fundamentals.

## Users, groups, and UIDs

Every process runs as a user (UID) and group (GID). Root is UID 0. This is the single most important idea for container security:

- A container that runs as **root (UID 0)** and escapes its isolation has root on the node's kernel. That's why `runAsNonRoot: true` and a numeric `runAsUser` are the first things Pod Security Admission and Kyverno check (`pod-securitycontext`, `pod-psa`).
- `id`, `whoami`, `/etc/passwd` — who am I and what groups am I in.
- **File ownership + permission bits** (`rwx` for user/group/other, seen in `ls -l`): `chmod`, `chown`. A world-readable secret file (`-rw-rw-rw-`) is a finding; mounted Kubernetes Secrets default to mode `0644`, which is why sensitive mounts set `defaultMode: 0400`.
- **setuid/setgid** bits let a binary run as its owner regardless of the caller — a classic privilege-escalation surface, which is why hardened images drop them and `securityContext` sets `allowPrivilegeEscalation: false`.

## Processes, namespaces, and capabilities

- Processes: `ps aux`, `top`, signals (`kill -TERM`, `kill -9`). Tetragon can send `SIGKILL` to a process the moment it does something disallowed (`rt-tetragon`) — same signal, enforced by eBPF.
- **Namespaces** (pid, net, mnt, user, …) are what make a container look like its own machine. **cgroups** cap its CPU/memory. "A container is a namespaced, cgroup-limited process" is worth internalizing now — it's why `kubectl exec` into a pod drops you into that process's namespaces.
- **Linux capabilities** split root's power into units (`CAP_NET_ADMIN`, `CAP_SYS_ADMIN`, …). Hardened workloads `drop: ["ALL"]` and add back only what's needed (`pod-securitycontext`). `getcap`/`man 7 capabilities` are the references.

## The shell and the filesystem

- Navigation and files: `cd`, `ls`, `find`, `grep`, `cat`, `less`, `cp`, `mv`, `rm`.
- **Pipes and redirection** (`|`, `>`, `>>`, `2>&1`) and filters (`grep`, `awk`, `sed`, `cut`, `sort`, `uniq`, `jq` for JSON) — you'll compose these constantly to slice logs and `kubectl -o json` output.
- Environment variables (`export`, `env`) — how config and (too often) secrets reach a process; seeing a secret in `env` is exactly what image/secret scanning flags (`data-secretscan`).
- `/etc` (config), `/var/log` (logs), `/proc` and `/sys` (kernel/process state — how tools like Falco and node exporters see the system).

## systemd and logs

- `systemctl status|start|stop <unit>` — manage services on a real host (Docker, the kubelet, Wazuh's manager all run this way).
- **`journalctl`** — the system journal. `journalctl -u docker`, `journalctl -f` (follow), `journalctl --since "10 min ago"`. You will read a *lot* of logs this course; the Kubernetes equivalent is `kubectl logs`, but node-level troubleshooting is `journalctl`.

## Networking from the shell

The tools you'll reach for in every networking and detection lab:

- `ip addr` / `ip route` — interfaces and routes. `ss -tulpn` — listening sockets and the process behind each port (the modern `netstat`).
- `curl -v` / `wget` — make an HTTP request and see headers/TLS; the workhorse for proving a NetworkPolicy allows or denies (`net-policy`) and that a WAF returns `403` (`waf-verify`).
- `dig` / `nslookup` — DNS. Cluster DNS (CoreDNS) resolution is the #1 thing a default-deny egress policy breaks (`net-policy`).
- `nc` (netcat), `ping`, `tcpdump` — connectivity and packet inspection; Suricata and Zeek (`nid-*`) do this at scale, but knowing the manual tools makes their output readable.

## Why this matters

Everything downstream is a Linux abstraction: `securityContext` is UID/GID/capabilities/seccomp; a NetworkPolicy is packet filtering; a Falco alert is a syscall; a Secret mount is a file with permission bits; a Vault agent is a sidecar process sharing a mount namespace. Fluency here is what turns the security labs from "type the commands" into "understand what the control actually does."

## Self-check

1. A pod runs as UID 0 with `allowPrivilegeEscalation: true`. Name two things an attacker who compromises it can attempt that a non-root, `drop: ["ALL"]` pod cannot.
2. Which command shows the process listening on a given port, and which shows the logs of a systemd-managed service?
3. You apply a default-deny egress NetworkPolicy and the app breaks even for allowed destinations. What Linux/networking fundamental is the usual culprit, and how would you confirm it from the shell?
4. What does it mean, in Linux terms, to say "a container is just a process"?

## Primary sources
- [The Linux Command Line (Shotts) — free book](https://linuxcommand.org/tlcl.php)
- [Linux Journey — "The Shell" lesson](https://linuxjourney.com/lesson/the-shell) — interactive fundamentals
- [Bash Reference Manual (GNU)](https://www.gnu.org/software/bash/manual/bash.html)
- [man7.org — Linux man pages](https://man7.org/linux/man-pages/)
