# Lab d4: Network threat detection with Suricata + Zeek

Run a signature IDS and a network-analysis framework on the same traffic: make Suricata fire an alert on a rule you wrote, then use Zeek's protocol logs to spot the same activity behaviorally — the alarm and the DVR, side by side.

**Objectives covered**

| id | Objective |
|---|---|
| `nid-suricata` | Detect and optionally block malicious traffic with an IDS/IPS |
| `nid-zeek` | Analyze network behavior and produce protocol logs |

**SC-500 correspondence**: Azure Firewall Premium IDPS / network threat detection (Suricata), network security monitoring — NSG/VNet flow logs + Traffic Analytics, the behavioral telemetry Defender/Sentinel hunt over (Zeek).

**Prerequisites**
- Docker + Docker Compose.
- [`lab-infra/network-detection`](../lab-infra/network-detection/) up (`cd lab-infra/network-detection && ./up.sh`).
- A test PCAP (the stack ships one) or the ability to `curl` a benign test indicator from inside the monitored network.
- Notes read: [network-detection.md](../domains/4-posture-monitoring/network-detection.md).

**Estimated time**: 1.5–2 h · $0 (local)

> **Resource note:** light compared to the SIEM/observability stacks (~1 GB), but if you want Suricata/Zeek alerts to flow *into* Wazuh/OpenSearch, do that as a follow-on — don't run the SIEM and this simultaneously unless your host has headroom.

## Steps

### Part A — Suricata IDS: fire an alert (`nid-suricata`)
1. `cd lab-infra/network-detection && ./up.sh` brings up the `suricata` and `zeek` containers (`docker compose -p oss500`), both reading the same interface/PCAP.
2. Update the ruleset: `docker compose -p oss500 exec suricata suricata-update` pulls **ET Open**. Confirm rules loaded: `docker compose -p oss500 exec suricata suricatasc -c ruleset-stats` (or check startup logs for the rule count).
3. Read the custom rule in [`suricata/rules/local.rules`](../lab-infra/network-detection/suricata/rules/local.rules):
   ```
   alert http $HOME_NET any -> $EXTERNAL_NET any (msg:"OSS500 Test - curl to known-bad host"; \
     flow:established,to_server; http.host; content:"testmynids.org"; sid:9000001; rev:1;)
   ```
   Dissect it: action (`alert`) · header (proto/IP/port/direction) · options (`msg`, `content`, `sid`, `rev`).
4. Trigger it. Either replay the shipped PCAP — `docker compose -p oss500 exec suricata suricata -r /pcaps/testmynids.pcap -l /var/log/suricata` — or from a host on the monitored network run the classic benign test: `curl -s http://testmynids.org/uid/index.html`.
5. Confirm the alert in **EVE JSON**: `docker compose -p oss500 exec suricata cat /var/log/suricata/eve.json | grep '"event_type":"alert"'` — you see the alert with your `signature`, `src_ip`, `dest_ip`, and `classtype`. (The ET Open ruleset also fires its own `GPL ATTACK_RESPONSE id check returned root`-style test signatures on that URL.)
6. Understand the mode: this is **IDS mode** (passive, reading a tap/PCAP — alerts only). Read the commented `nid-suricata` note in [`suricata/suricata.yaml`](../lab-infra/network-detection/suricata/suricata.yaml) explaining how `af-packet` IDS differs from inline **IPS** (`nfqueue` + `drop` action), and why inline can block but sits in the failure path.

### Part B — Zeek behavioral logs (`nid-zeek`)
7. Zeek processed the same traffic. List its logs: `docker compose -p oss500 exec zeek ls /usr/local/zeek/logs/current/` — `conn.log`, `dns.log`, `http.log`, `ssl.log`, `files.log`, `weird.log`, `notice.log`.
8. Find the same activity *without a signature*: `docker compose -p oss500 exec zeek cat /usr/local/zeek/logs/current/http.log` and locate the request to `testmynids.org` — host, URI, user-agent, response. Zeek logged the *behavior*; it needed no rule.
9. Inspect `conn.log` — the flow record (who talked to whom, bytes, duration). This is the flow-log analogue you'd hunt over for beaconing/exfil: `... | awk '{print $3, $5, $6, $10}'` to eyeball src/dst/bytes.
10. Contrast the two tools explicitly: Suricata told you *"a known-bad signature matched"*; Zeek gave you *"here is everything that happened"* so you could find an anomaly with no signature at all. Both ran on the same packets.

### Part C — (Optional) ship to the SIEM
11. If the SIEM stack is up with host headroom, point a Wazuh agent / log collector at `eve.json` and Zeek's JSON logs so network alerts become hunt material in OpenSearch (`siem-hunt`). This is the integration Domain 4 builds toward; skip if RAM is tight.

## Verification
- **Suricata**: an `event_type:"alert"` record in `eve.json` for the `testmynids.org` request — your `sid:9000001` (and/or ET Open test signatures) fired on the PCAP/curl. *(A Suricata alert on a known test indicator is the observable proof.)*
- **Zeek**: the same request is present in `http.log` and the flow in `conn.log`, demonstrating behavioral logging with no signature required.
- You can state, for a given scenario, whether Suricata IDS/IPS or Zeek is the right tool and why.

## Teardown
- `cd lab-infra/network-detection && ./down.sh` (`docker compose -p oss500 down -v`).

> **Validate it *(purple team)*.** Generate the traffic these signatures should catch in [`d5-infra-attack-simulation`](d5-infra-attack-simulation.md): **ATT&CK T1046** (service discovery / scan) and **T1071** (app-layer C2 beacon) ↔ **D3FEND D3-NTA** — confirm Suricata `fast.log` fires.

## What the exam asks
- **IDS vs IPS** is the core distinction: IDS = passive, out-of-band (mirror/tap), *alerts only*; IPS = inline, in the data path, can `drop`/`reject` — prevention at the cost of being a failure point. A mirror can never block.
- Suricata is **signature/known-threat** driven — the **ruleset is the detection content** (ET Open + `suricata-update`); stale rules detect nothing. EVE JSON feeds the SIEM.
- **Zeek logs behavior, it doesn't block** — `conn/dns/http/ssl.log` are for hunting and enrichment. "Detect a novel beacon with no signature" → Zeek; "block a known exploit inline" → Suricata IPS.
- They're **complementary on the same tap**: Suricata for precision on known threats, Zeek for breadth/context. Zeek ≈ flow logs / NSM; Suricata ≈ Azure Firewall Premium IDPS.
