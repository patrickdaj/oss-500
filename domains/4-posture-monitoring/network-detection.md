# Detect threats on the network

Domain 4, subsection 3 (`d4-network-detection`). Endpoint and cluster telemetry miss what happens on the wire: C2 beacons, exfiltration, lateral movement, exploit traffic. Network security monitoring fills that gap with two complementary open-source tools — **Suricata**, a signature-and-protocol **IDS/IPS** that alerts (or blocks) on known-bad traffic, and **Zeek**, a network-analysis framework that turns raw packets into rich, structured **protocol logs** for behavioral analysis and hunting. Together they cover the SC-500 "detect network threats" surface. Primary lab: [d4-network-detection](../../labs/d4-network-detection.md) on [`lab-infra/network-detection`](../../lab-infra/network-detection/) (Suricata + Zeek via Docker Compose).

## Detect and optionally block malicious traffic with an IDS/IPS

*Objective: `nid-suricata` · OSS: Suricata ≈ SC-500: Network threat detection · Lab: [d4-network-detection](../../labs/d4-network-detection.md)*

**Suricata** inspects traffic against a **ruleset** of signatures. Each rule is one line: an *action* (`alert`, `drop`, `reject`, `pass`), a *header* (protocol, source/dest IP and port, direction — `alert http $HOME_NET any -> $EXTERNAL_NET any`), and *options* in parentheses (`msg`, `content` byte-matches, `pcre`, protocol keywords, `flow`, `sid`, `rev`, `classtype`). Rulesets come from feeds — **Emerging Threats (ET) Open** is the free default, managed with `suricata-update`. Beyond signatures, Suricata does **protocol detection and logging** (HTTP, TLS/JA3, DNS, files) and emits structured **EVE JSON** (`eve.json`) with `event_type: alert|http|dns|tls|flow`, which ships straight into a SIEM (Wazuh/OpenSearch from `d4-siem`).

The mode distinction is exam-critical. **IDS mode** is passive: Suricata reads a copy of traffic from a SPAN/mirror port or an `AF_PACKET` tap and *alerts* — it sees everything but blocks nothing. **IPS mode** is inline: traffic passes *through* Suricata (via NFQUEUE/`nftables` or two bridged interfaces), so `drop`/`reject` actions actually stop packets — detection **and** prevention, at the cost of being in the data path (latency, a failure = an outage). You choose per deployment: a mirror for visibility, inline for enforcement. In the lab you run IDS mode against a live interface or replay a PCAP and watch an alert fire on a rule you wrote.

SC-500 mapping: Suricata ≈ **Azure network threat detection** — the IDPS feature of **Azure Firewall Premium** (signature-based intrusion detection and prevention) and the network-layer detections in **Defender for Cloud / Microsoft Defender XDR**. Suricata rules ≈ Azure Firewall IDPS signatures; IDS-vs-IPS ≈ Azure Firewall IDPS "Alert" vs "Alert and deny" modes. Suricata EVE JSON into a SIEM ≈ network alerts flowing into Sentinel.

Exam gotchas:
- **IDS (detect/alert, passive, out-of-band) vs IPS (prevent/drop, inline, in-path)** is the single most-tested distinction. Inline enables blocking but puts you in the failure path; a mirror can never block. Match the mode to "alert only" vs "must stop it."
- Suricata is **signature/known-threat-oriented** (plus protocol anomaly). It's strong on *known* bad; novel/behavioral detection is where Zeek complements it.
- The **ruleset is the detection content** — an IDS with stale/no rules detects nothing. `suricata-update` + ET Open is the maintenance answer; `sid`/`rev` version rules like code.

**Resources:**
- [Suricata — what is Suricata / features](https://docs.suricata.io/en/latest/what-is-suricata.html) (~10 min)
- [Suricata rules format](https://docs.suricata.io/en/latest/rules/intro.html) (~20 min)
- [Suricata IPS/inline (NFQUEUE)](https://docs.suricata.io/en/latest/setup-guides/nftables.html) (~15 min)

## Analyze network behavior and produce protocol logs

*Objective: `nid-zeek` · OSS: Zeek ≈ SC-500: Network security monitoring · Lab: [d4-network-detection](../../labs/d4-network-detection.md)*

**Zeek** (formerly Bro) is not primarily a signature matcher — it's a network-analysis framework that observes traffic and produces a **structured record of everything that happened**. Out of the box it writes per-protocol logs: `conn.log` (every connection — the who-talked-to-whom flow record), `dns.log`, `http.log`, `ssl.log` (with JA3/certs), `files.log`, `x509.log`, `notice.log`, `weird.log`, and more. These logs are the substrate of network security monitoring and threat hunting: you don't need a signature to notice a host suddenly beaconing to a rare domain every 60 seconds, or a TLS cert that doesn't match its SNI, or a 2 GB upload at 3 a.m. — the behavior is right there in `conn.log`/`ssl.log`/`dns.log`. Zeek is also **scriptable** (its own event-driven language), so you can write detections on protocol events, and it ships intel-framework matching against IOC feeds.

The mental model: **Suricata answers "did any known-bad signature match?"; Zeek answers "tell me everything that happened on the network so I can find the anomaly."** Suricata is the alarm on the door; Zeek is the DVR that recorded the whole building. In practice you run both on the same tap — Suricata for known threats, Zeek logs for hunting and for enriching every Suricata alert with full connection context. Zeek logs (TSV or JSON) ship into the SIEM and become hunt material for `siem-hunt`.

SC-500 mapping: Zeek ≈ **network security monitoring / flow analytics** — the behavioral, log-everything side that in Azure is approximated by **VNet flow logs / NSG flow logs + Traffic Analytics** and the network telemetry Defender/Sentinel hunt over. Zeek `conn.log` ≈ flow logs (connection metadata), Zeek's richer protocol logs (`dns.log`, `http.log`, `ssl.log`) ≈ the deeper protocol telemetry you'd centralize in a Log Analytics workspace for hunting. Where Suricata ≈ IDPS (signatures), Zeek ≈ the "record and analyze behavior" half.

Exam gotchas:
- **Zeek logs behavior; it does not, by default, block or even alert on signatures.** "Detect a novel beacon with no signature" → Zeek (behavioral logs), not Suricata. "Block a known exploit" → Suricata IPS.
- Zeek's value is **breadth of context** (`conn.log` + protocol logs), ideal for hunting and incident enrichment — pair it with Suricata's precision. They're complementary, not either/or.
- Zeek is **scriptable/extensible** and does **IOC/intel matching** — but it's a framework, not a turnkey blocker. Recognize it as "network security monitoring / metadata," the flow-log analogue.

**Resources:**
- [Zeek — about / overview](https://docs.zeek.org/en/master/about.html) (~10 min)
- [Zeek log files reference](https://docs.zeek.org/en/master/logs/index.html) (~20 min)
- [Zeek — monitoring HTTP/DNS traffic (get started)](https://docs.zeek.org/en/master/quickstart.html) (~15 min)

## Summary
| Objective | Takeaway |
|---|---|
| `nid-suricata` | Signature IDS/IPS; rule = action+header+options, ET Open feed, EVE JSON to SIEM; IDS (passive alert) vs IPS (inline drop); ≈ Azure Firewall Premium IDPS |
| `nid-zeek` | Network-analysis framework producing rich protocol logs (`conn/dns/http/ssl.log`) for behavioral hunting; logs, doesn't block; ≈ NSM / flow logs + Traffic Analytics |
