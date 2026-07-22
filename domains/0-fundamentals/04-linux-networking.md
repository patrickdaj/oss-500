# Fundamentals: Linux networking — the substrate under the cloud fabric

Ramp notes — no exam objective maps here. Enough Linux networking to see what a **VPC, subnet, route table, and NAT gateway actually are** before Cilium (`fab-*`) and the cloud abstracts them away. A cloud virtual network is not magic: it's namespaces, bridges, addresses, routes, and NAT — the same primitives Kubernetes and Cilium build on. Read this before [`network-fabric.md`](../2-secrets-data-networking/network-fabric.md) and the [d2-network-fabric](../../labs/d2-network-fabric.md) lab.

## Network namespaces — the isolation primitive (≈ a VPC/VNet)

A **network namespace** (netns) is a private copy of the whole network stack: its own interfaces, routing table, and firewall rules. Two processes in different netns can't see each other's traffic — the kernel isolates them.

- `ip netns add blue` / `ip netns exec blue ip addr` — create one, run a command inside it.
- A **container is a process in its own netns** (plus pid/mnt/user namespaces + cgroups — see [`01-containers.md`](01-containers.md)). "A pod has its own IP" means "the pod's containers share one netns with its own stack."
- **Cloud mapping:** a **VPC/VNet is isolation at scale** — the cloud's version of "this network is separate from that one." A netns is the same idea on one host; a VPC is the same idea across a datacenter.

## veth, bridges, and the pod network (≈ a subnet)

Namespaces are joined with a **veth pair** — a virtual cable: a packet into one end comes out the other. One end sits in the container's netns, the other on the host, plugged into a **bridge** (a virtual switch, e.g. `cni0`/`docker0`). Every pod on a node hangs off that bridge, so pods on a node talk L2 like hosts on a switch.

- `ip link add veth0 type veth peer name veth1`; `bridge link` / `ip link show type bridge`.
- **Cloud mapping:** a **subnet** is a broadcast/routing domain inside the VPC — the bridge + its address range is the on-host analog. kind gives each node a **PodCIDR** (a slice of `10.244.0.0/16`); that slice is the node's "subnet," and Cilium's IPAM hands pod IPs out of it (`fab-cni`).

## CIDR and subnetting — addressing the fabric

An address block is written **CIDR**: `10.244.0.0/16` = the `/16` prefix is fixed (network), the low 16 bits vary (hosts) → 65,536 addresses. Split a `/16` into `/24`s to give each node its own non-overlapping range.

- `10.0.0.0/8` (16M), `172.16.0.0/12`, `192.168.0.0/16` are the **RFC 1918 private** ranges clouds carve VPCs from; `203.0.113.0/24` and friends are RFC 5737 **documentation** ranges (used as placeholders in the lab policies).
- `ipcalc 10.244.0.0/16` or just reason about the mask; **non-overlapping CIDRs** are what make routing and peering unambiguous — overlapping ranges are the #1 reason a VNet peering or Cluster Mesh (`fab-peering`) can't be established.
- **Cloud mapping:** designing VPC/subnet CIDRs (address plan, no overlaps, room to grow) is exactly this — the `destinationCIDRs` in the egress-gateway policy (`fab-egress`) is a CIDR match on where traffic is going.

## Routing — `ip route` (≈ a route table)

A **route table** answers "for a destination IP, which interface / next hop?" The kernel picks the most specific matching prefix.

```bash
ip route                     # the host's route table
# default via 192.168.65.1 dev eth0     <- the default route: everything not local
# 10.244.1.0/24 dev cni0                <- pods on this node: go to the bridge
ip route get 1.1.1.1         # show which route a packet to 1.1.1.1 would take
```

- The **default route** (`0.0.0.0/0`) is where "the internet" goes — the cloud's **default route to a NAT gateway / internet gateway** is the same line.
- **Cloud mapping:** a cloud **route table** attached to a subnet is `ip route` at cloud scale; a **VNet peering** adds routes so two VPCs' CIDRs reach each other — routing, not a tunnel. Hub-spoke = a route table pointing spokes at a hub appliance.

## NAT and `MASQUERADE` (≈ a NAT gateway)

Private pods/hosts can't appear on the internet with `10.x` source addresses, so on the way out the kernel **rewrites the source IP** to a routable one — **SNAT**. `MASQUERADE` is SNAT to "whatever the egress interface's IP is."

```bash
# classic iptables SNAT: pods leave with the node's external IP
iptables -t nat -A POSTROUTING -s 10.244.0.0/16 -o eth0 -j MASQUERADE
```

- This is precisely what a **cloud NAT gateway** does: many private instances egress the internet through **one known, stable public IP**, and unsolicited inbound is not possible. Fixing that egress IP (so a partner can allowlist it, and so egress is attributable) is the security control.
- **Cloud mapping / the lab:** Cilium's **Egress Gateway** (`fab-egress`) is MASQUERADE with a *pinned* IP and pod-selection — SNAT to one gateway node so an external listener always sees the same source. `bpf.masquerade: true` in the Helm values is "do this SNAT in eBPF instead of iptables."

## Putting it together (what the fabric lab builds)

| Linux primitive | Command | Cloud construct | Objective |
|---|---|---|---|
| network namespace | `ip netns` | VPC/VNet isolation | `fab-cni` |
| veth + bridge | `ip link`, `bridge` | subnet / node PodCIDR | `fab-cni` |
| CIDR block | address plan | VPC/subnet addressing | (all) |
| route table | `ip route` | route table / peering | `fab-peering` |
| SNAT / MASQUERADE | `iptables -t nat` | NAT gateway (fixed egress IP) | `fab-egress` |
| stateful filter | `nft`/`iptables` | cloud/host firewall | `fab-fqdn` |

Every cloud-network control in Domain 2 is one of these primitives, managed at scale and by API. Cilium implements them in **eBPF** (faster, identity-aware) instead of iptables, but the model is identical — which is why seeing the primitive once makes the abstraction stop being magic.

## Self-check

1. In Linux terms, what is a "VPC," and what one-command primitive isolates two networks on a single host?
2. A pod at `10.244.1.7` reaches `1.1.1.1` and the remote server logs the source as your node's public IP. Which mechanism rewrote the address, and what is the cloud service that does this at scale?
3. You want two clusters' pods (`10.244.0.0/16` each) to route to each other. Why is identical CIDR on both a problem, and which cloud/Cilium feature does the join?
4. Which `ip` command shows the route a packet to a given destination would actually take, and why is the `0.0.0.0/0` route special?

## Primary sources
- [ip-netns(8) — network namespaces](https://man7.org/linux/man-pages/man8/ip-netns.8.html)
- [Linux Advanced Routing & Traffic Control (LARTC)](https://lartc.org/howto/)
- [nftables / iptables NAT (netfilter.org)](https://wiki.nftables.org/wiki-nftables/index.php/Performing_Network_Address_Translation_(NAT))
- [Julia Evans — "Networking! ACK!" zine](https://wizardzines.com/zines/networking/)
- [A Container Networking Overview (from a pod's veth to the bridge)](https://labs.iximiuz.com/tutorials/container-networking-from-scratch)
