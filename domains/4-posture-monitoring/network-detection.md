# Detect threats on the network

Domain 4, subsection 3 (`d4-network-detection`). Endpoint and cluster telemetry miss what happens on the wire: C2 beacons, exfiltration, lateral movement, exploit traffic. Network security monitoring fills that gap with two complementary open-source tools — **Suricata**, a signature-and-protocol **IDS/IPS** that alerts (or blocks) on known-bad traffic, and **Zeek**, a network-analysis framework that turns raw packets into rich, structured **protocol logs** for behavioral analysis and hunting. Together they cover the SC-500 "detect network threats" surface. Primary lab: [d4-network-detection](../../labs/d4-network-detection.md) on [`lab-infra/network-detection`](../../lab-infra/network-detection/) (Suricata + Zeek via Docker Compose).

## Detect and optionally block malicious traffic with an IDS/IPS

*Objective: `nid-suricata` · OSS: Suricata ≈ SC-500: Network threat detection · Lab: [d4-network-detection](../../labs/d4-network-detection.md)*

**Suricata** inspects traffic against a **ruleset** of signatures. Each rule is one line: an *action* (`alert`, `drop`, `reject`, `pass`), a *header* (protocol, source/dest IP and port, direction), and *options* in parentheses (`msg`, `content` byte-matches, `pcre`, protocol keywords, `flow`, `sid`, `rev`, `classtype`). A concrete rule — detect a common reverse-shell over HTTP and tag it to ATT&CK:

```
alert http $HOME_NET any -> $EXTERNAL_NET any ( \
  msg:"ET POLICY curl User-Agent Outbound"; \
  flow:established,to_server; \
  http.user_agent; content:"curl/"; startswith; \
  classtype:policy-violation; sid:1000001; rev:1; \
  metadata: mitre_technique_id T1071; )
```

Read it left to right: *action* `alert`, *header* `http $HOME_NET any -> $EXTERNAL_NET any` (HTTP from the home net outbound), then *options* — `flow:established,to_server` scopes to client requests, the `http.user_agent` sticky buffer + `content:"curl/"` is the byte match, and `sid`/`rev` version it like code. Rulesets come from feeds — **Emerging Threats (ET) Open** is the free default, managed with `suricata-update` (`suricata-update` fetches, `suricata-update list-sources` shows feeds, `-T "suricata -T"` tests before reload). Beyond signatures, Suricata does **protocol detection and logging** (HTTP, TLS/JA3, DNS, files) and emits structured **EVE JSON** (`eve.json`), which ships straight into a SIEM (Wazuh/OpenSearch from `d4-siem`). An alert event looks like:

```json
{"timestamp":"2026-07-21T03:14:00Z","event_type":"alert","src_ip":"10.0.0.5","dest_ip":"93.184.216.34",
 "alert":{"signature":"ET POLICY curl User-Agent Outbound","category":"policy-violation","signature_id":1000001},
 "http":{"hostname":"evil.example","user_agent":"curl/8.5.0"}}
```

Suricata is **multi-threaded** (unlike legacy Snort) and typically captures via `AF_PACKET` (Linux) or `AF_XDP`/DPDK at higher rates; `event_type: alert|http|dns|tls|flow` records let you both alert *and* keep protocol metadata for hunting.

The mode distinction is exam-critical. **IDS mode** is passive: Suricata reads a copy of traffic from a SPAN/mirror port or an `AF_PACKET` tap and *alerts* — it sees everything but blocks nothing. **IPS mode** is inline: traffic passes *through* Suricata (via NFQUEUE/`nftables` or two bridged AF_PACKET interfaces), so `drop`/`reject` actions actually stop packets — detection **and** prevention, at the cost of being in the data path (latency, a failure = an outage). Inline requires the kernel to hand packets to Suricata: an `nftables` rule `queue num 0` sends flows to `NFQUEUE`, and Suricata run with `-q 0` issues verdicts. `drop` silently discards; `reject` actively tears down with a RST/ICMP. You choose per deployment: a mirror for visibility, inline for enforcement. In the lab you run IDS mode against a live interface or replay a PCAP (`suricata -r sample.pcap -S local.rules`) and watch an alert fire on a rule you wrote.

SC-500 mapping: Suricata ≈ **Azure network threat detection** — the IDPS feature of **Azure Firewall Premium** (signature-based intrusion detection and prevention) and the network-layer detections in **Defender for Cloud / Microsoft Defender XDR**. Suricata rules ≈ Azure Firewall IDPS signatures; IDS-vs-IPS ≈ Azure Firewall IDPS "Alert" vs "Alert and deny" modes; `$HOME_NET`/`$EXTERNAL_NET` ≈ the private-range/internet distinction the firewall makes automatically. Suricata EVE JSON into a SIEM ≈ network alerts flowing into Sentinel.

Exam gotchas:
- **IDS (detect/alert, passive, out-of-band) vs IPS (prevent/drop, inline, in-path)** is the single most-tested distinction. Inline enables blocking but puts you in the failure path; a mirror can never block. Match the mode to "alert only" vs "must stop it."
- Suricata is **signature/known-threat-oriented** (plus protocol anomaly). It's strong on *known* bad; novel/behavioral detection is where Zeek complements it.
- The **ruleset is the detection content** — an IDS with stale/no rules detects nothing. `suricata-update` + ET Open is the maintenance answer; `sid`/`rev` version rules like code.
- **`drop` vs `reject`**: `drop` silently discards (attacker sees a timeout), `reject` sends a RST/ICMP (faster failure, but reveals the sensor). Both require IPS/inline mode — neither does anything on a mirror.
- **Encrypted traffic limits DPI**: on TLS, Suricata sees the handshake (SNI, JA3, cert) but not the payload. "Inspect encrypted C2 content" needs TLS interception or falls back to metadata/JA3 fingerprinting, not `content:` payload matches.
- `$HOME_NET`/`$EXTERNAL_NET` are variables in `suricata.yaml` — a misconfigured `$HOME_NET` makes directional rules (`->`) match nothing. A frequent "my rule never fires" root cause alongside a stale ruleset.

**Resources:**
- [Suricata — what is Suricata / features](https://docs.suricata.io/en/latest/what-is-suricata.html) (~10 min)
- [Suricata rules format & intro](https://docs.suricata.io/en/latest/rules/intro.html) (~20 min)
- [suricata-update — rule management](https://docs.suricata.io/en/latest/rule-management/suricata-update.html) (~15 min)
- [EVE JSON output format](https://docs.suricata.io/en/latest/output/eve/eve-json-output.html) (~15 min)
- [Suricata IPS/inline setup (NFQUEUE/nftables)](https://docs.suricata.io/en/latest/setup-guides/nftables.html) (~15 min)
- [Azure Firewall Premium IDPS](https://learn.microsoft.com/en-us/azure/firewall/premium-features#idps) (~10 min)

## Analyze network behavior and produce protocol logs

*Objective: `nid-zeek` · OSS: Zeek ≈ SC-500: Network security monitoring · Lab: [d4-network-detection](../../labs/d4-network-detection.md)*

**Zeek** (formerly Bro) is not primarily a signature matcher — it's a network-analysis framework that observes traffic and produces a **structured record of everything that happened**. Out of the box it writes per-protocol logs: `conn.log` (every connection — the who-talked-to-whom flow record), `dns.log`, `http.log`, `ssl.log` (with JA3/certs), `files.log`, `x509.log`, `notice.log`, `weird.log`, and more. A `conn.log` line is the flow-record backbone — key fields:

```
ts  uid  id.orig_h  id.orig_p  id.resp_h  id.resp_p  proto  service  duration  orig_bytes  resp_bytes  conn_state
```

That `uid` is the join key: it appears in every other log for the same connection, so you pivot from a suspicious `dns.log` query to the exact `conn.log` flow and `ssl.log` handshake. These logs are the substrate of network security monitoring and threat hunting: you don't need a signature to notice a host suddenly beaconing to a rare domain every 60 seconds, or a TLS cert that doesn't match its SNI, or a 2 GB upload at 3 a.m. — the behavior is right there in `conn.log`/`ssl.log`/`dns.log`. Zeek is also **scriptable** (its own event-driven language): you hook protocol events to write custom detections —

```zeek
event dns_request(c: connection, msg: dns_msg, query: string, qtype: count, qclass: count) {
    if ( |query| > 50 )   # long labels → possible DNS tunneling / exfil (ATT&CK T1071.004)
        NOTICE([$note=DNS::Long_Query, $conn=c, $msg=fmt("Long DNS query: %s", query)]);
}
```

and it ships an **Intel Framework** that matches connection fields against IOC feeds (domains, IPs, hashes) and writes hits to `intel.log`.

The mental model: **Suricata answers "did any known-bad signature match?"; Zeek answers "tell me everything that happened on the network so I can find the anomaly."** Suricata is the alarm on the door; Zeek is the DVR that recorded the whole building. In practice you run both on the same tap — Suricata for known threats, Zeek logs for hunting and for enriching every Suricata alert with full connection context. Zeek logs (TSV or JSON) ship into the SIEM and become hunt material for `siem-hunt` — e.g. an OpenSearch `terms` aggregation on `conn.log` `id.resp_h` to find beaconing to rare destinations, or a `cardinality` on `query` per host to spot DNS tunneling. Deploy at scale via the **Zeek Cluster** (a manager, proxies, and multiple worker processes load-balanced across a high-traffic tap) since a single process can't keep up with a busy link.

SC-500 mapping: Zeek ≈ **network security monitoring / flow analytics** — the behavioral, log-everything side that in Azure is approximated by **VNet flow logs / NSG flow logs + Traffic Analytics** and the network telemetry Defender/Sentinel hunt over. Zeek `conn.log` ≈ flow logs (connection metadata), Zeek's richer protocol logs (`dns.log`, `http.log`, `ssl.log`) ≈ the deeper protocol telemetry you'd centralize in a Log Analytics workspace for hunting. Zeek's Intel Framework ≈ Sentinel/Defender **threat-intelligence indicator matching**. Where Suricata ≈ IDPS (signatures), Zeek ≈ the "record and analyze behavior" half.

Exam gotchas:
- **Zeek logs behavior; it does not, by default, block or even alert on signatures.** "Detect a novel beacon with no signature" → Zeek (behavioral logs), not Suricata. "Block a known exploit" → Suricata IPS.
- Zeek's value is **breadth of context** (`conn.log` + protocol logs), ideal for hunting and incident enrichment — pair it with Suricata's precision. They're complementary, not either/or.
- Zeek is **scriptable/extensible** and does **IOC/intel matching** (Intel Framework → `intel.log`) — but it's a framework, not a turnkey blocker. Recognize it as "network security monitoring / metadata," the flow-log analogue.
- The **`uid` correlates all logs** for one connection — the pivot key that makes Zeek data hunt-friendly. `conn_state` (S0, SF, REJ, RSTO…) encodes how a flow ended and is a rich anomaly signal (lots of S0 = scanning).
- Even on **encrypted** traffic Zeek still yields high-value metadata — `ssl.log` (JA3/JA3S, SNI, cert), connection sizes/timing, DNS — so behavioral detection survives TLS where Suricata payload matching does not.
- Zeek does **not capture full packets** by default — it distills packets into logs. "Retain full PCAP" is a separate capture concern (e.g. `Arkime`/`tcpdump`), not Zeek's default output.

**Resources:**
- [Zeek — about / overview](https://docs.zeek.org/en/master/about.html) (~10 min)
- [Zeek log files reference](https://docs.zeek.org/en/master/logs/index.html) (~20 min)
- [Zeek quickstart — monitoring HTTP/DNS](https://docs.zeek.org/en/master/quickstart.html) (~15 min)
- [Zeek scripting basics](https://docs.zeek.org/en/master/scripting/basics.html) (~25 min)
- [Zeek Intel Framework (IOC matching)](https://docs.zeek.org/en/master/frameworks/intel.html) (~15 min)
- [MITRE ATT&CK — Command and Control tactic (TA0011)](https://attack.mitre.org/tactics/TA0011/) (~15 min)

## Summary
| Objective | Takeaway |
|---|---|
| `nid-suricata` | Signature IDS/IPS; rule = action+header+options, ET Open feed, EVE JSON to SIEM; IDS (passive alert) vs IPS (inline drop); ≈ Azure Firewall Premium IDPS |
| `nid-zeek` | Network-analysis framework producing rich protocol logs (`conn/dns/http/ssl.log`) for behavioral hunting; logs, doesn't block; ≈ NSM / flow logs + Traffic Analytics |
