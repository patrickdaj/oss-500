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

## Challenge

Get Suricata to alert on one specific piece of traffic using a signature *you* write, then find that same traffic in Zeek's logs with no signature at all — the alarm and the DVR, on the same packets.

- **Suricata (`nid-suricata`)**: write and load a custom HTTP rule that fires when a host on your monitored network requests `testmynids.org`, then generate that traffic. Observable: an `event_type:"alert"` record in `eve.json` carrying your `signature`, `src_ip`, `dest_ip`, and `classtype`.
- **Zeek (`nid-zeek`)**: without writing any rule, locate the same request in Zeek's protocol logs and the flow record it produced. Observable: the request is present in `http.log` and the corresponding flow is in `conn.log`.
- Come out able to state, for a given scenario, whether Suricata IDS/IPS or Zeek is the right tool — and why a passive tap can alert but never block.

No rule text and no finished commands here — that's what you build next.

## Build it (guided)

### Part A — Suricata IDS: fire an alert (`nid-suricata`)
1. `cd lab-infra/network-detection && ./up.sh` brings up the `suricata` and `zeek` containers (`docker compose -p oss500`), both reading the same interface/PCAP.
2. **Goal**: get real detection content loaded — the Emerging Threats Open ruleset. `up.sh` already pulls it once on first boot, but rulesets go stale and you'll want to refresh it on demand. **Hint**: Suricata ships a dedicated rule-management CLI for exactly this. **Your turn**: find and run the command, inside the `suricata` container, that fetches/refreshes the ruleset, then confirm a nonzero rule count — either via a live socket query (`suricatasc`) or the container's startup logs.
3. **Now write your own rule instead of reading one.** Goal: an HTTP rule that alerts when a client on `$HOME_NET` requests a host containing `testmynids.org`. Rule anatomy is `ACTION  HEADER(proto src->dst)  (OPTIONS; sid; rev;)`:
   - **Action** — this is IDS mode. Which action keyword only alerts and never touches the packet?
   - **Header** — protocol `http`, source `$HOME_NET any`, direction `->`, destination `$EXTERNAL_NET any`.
   - **Options** — you'll need `flow:established,to_server;`, a way to match the request's `Host` header specifically (hint: there's a sticky buffer for exactly this, paired with a `content` match), a `msg`, and a **unique** `sid` (local rules conventionally live above `1000000`; this lab's custom rules use the `9000000` range) plus `rev:1;`.
   Sketch the complete rule text before you check anything against the shipped file.
4. Trigger it. Either replay the shipped PCAP — `docker compose -p oss500 exec suricata suricata -r /pcaps/testmynids.pcap -l /var/log/suricata` — or, from a host on the monitored network, run the classic benign test: `curl -s http://testmynids.org/uid/index.html`.
5. Confirm the alert in **EVE JSON**: `docker compose -p oss500 exec suricata cat /var/log/suricata/eve.json | grep '"event_type":"alert"'` — you should see your alert with its `signature`, `src_ip`, `dest_ip`, and `classtype`. (ET Open also fires its own `GPL ATTACK_RESPONSE`-style test signatures on that same URL — if that's all you see and not yours, check your `sid` range and that your rule file is actually on Suricata's load path.)
6. **Reason it out before you look it up.** This is **IDS mode** — passive, reading a tap/PCAP. Why can a mirror/tap alert but never block? What would have to change — data-path placement, the action keyword, the queuing mechanism — to turn this into inline **IPS**? Then check your reasoning against the commented `nid-suricata` note in [`suricata/suricata.yaml`](../lab-infra/network-detection/suricata/suricata.yaml).

### Part B — Zeek behavioral logs (`nid-zeek`)
7. Zeek processed the same traffic with no rule involved. List its logs yourself: `docker compose -p oss500 exec zeek ls /usr/local/zeek/logs/current/` — note which ones exist (`conn.log`, `dns.log`, `http.log`, `ssl.log`, `files.log`, `weird.log`, `notice.log`).
8. **Your turn**: find the `testmynids.org` request without a signature. Open `http.log` — `docker compose -p oss500 exec zeek cat /usr/local/zeek/logs/current/http.log` — and locate the record: host, URI, user-agent, response. Nothing alerted; you're reading behavior directly.
9. Now find that same activity's flow record in `conn.log` — who talked to whom, bytes, duration. This is the flow-log analogue you'd hunt over for beaconing/exfil at scale; pull the src/dst/bytes fields out (e.g. with `awk`) so you could eyeball a whole log's worth.
10. Put it in your own words: what did Suricata tell you that Zeek didn't, and vice versa? Both tools ran on the identical packets.

### Part C — (Optional) ship to the SIEM
11. If the SIEM stack is up with host headroom, work out how you'd point a Wazuh agent/log collector at `eve.json` and Zeek's JSON logs so network alerts become hunt material in OpenSearch (`siem-hunt`). This is the integration Domain 4 builds toward — treat it as directions only here; skip if RAM is tight.

## Verification
- **Suricata**: an `event_type:"alert"` record in `eve.json` for the `testmynids.org` request — your `sid:9000001` (and/or ET Open test signatures) fired on the PCAP/curl. *(A Suricata alert on a known test indicator is the observable proof.)*
- **Zeek**: the same request is present in `http.log` and the flow in `conn.log`, demonstrating behavioral logging with no signature required.
- You can state, for a given scenario, whether Suricata IDS/IPS or Zeek is the right tool and why.

## Reference solution
Build it yourself first; check after.

- **Custom Suricata rules** — [`suricata/rules/local.rules`](../lab-infra/network-detection/suricata/rules/local.rules) in [`lab-infra/network-detection/`](../lab-infra/network-detection/):
  ```
  alert http $HOME_NET any -> $EXTERNAL_NET any (msg:"OSS500 Test - HTTP request to testmynids.org"; \
      flow:established,to_server; http.host; content:"testmynids.org"; nocase; \
      classtype:policy-violation; sid:9000001; rev:1;)

  alert http $HOME_NET any -> $EXTERNAL_NET any (msg:"OSS500 Test - possible cleartext password in HTTP POST"; \
      flow:established,to_server; http.method; content:"POST"; http.request_body; content:"password="; nocase; \
      classtype:credential-theft; sid:9000002; rev:1;)

  alert dns $HOME_NET any -> any any (msg:"OSS500 Test - DNS query to .top TLD"; \
      dns.query; content:".top"; nocase; endswith; \
      classtype:bad-unknown; sid:9000003; rev:1;)
  ```
  The first rule is the one the challenge targets (dissect it: action `alert` · header `http $HOME_NET any -> $EXTERNAL_NET any` · options `msg`/`http.host`+`content`/`classtype`/`sid`/`rev`). The other two ship as further worked examples of the same anatomy: a credential-theft pattern in an HTTP POST body, and a suspicious-TLD DNS query.
- **Ruleset update** — `docker compose -p oss500 exec suricata suricata-update` (already run once by `up.sh`; re-run any time you add or change rules), confirmed with `docker compose -p oss500 exec suricata suricatasc -c ruleset-stats` (or the container's startup logs, which log the loaded rule count).
- **IDS vs IPS** — the commented `nid-suricata` note in [`suricata/suricata.yaml`](../lab-infra/network-detection/suricata/suricata.yaml): the active config uses `af-packet` (IDS — passive, out-of-band, alert-only); a commented-out `nfqueue` block shows what inline IPS needs instead — traffic actually queued through Suricata, plus every rule action changed from `alert` to `drop` — and why that puts Suricata in the failure path (a `fail-open` flag trades availability for security if it dies).

If your rule never fires: check your `sid` isn't a duplicate of an ET Open signature, that `local.rules` is actually listed under `rule-files` in `suricata.yaml`, and that you matched on the `http.host` sticky buffer (not a raw `content` search over the whole request) — that's the same buffer ET Open's own HTTP signatures rely on.

## Teardown
- `cd lab-infra/network-detection && ./down.sh` (`docker compose -p oss500 down -v`).

> **Validate it *(purple team)*.** Generate the traffic these signatures should catch in [`d5-infra-attack-simulation`](d5-infra-attack-simulation.md): **ATT&CK T1046** (service discovery / scan) and **T1071** (app-layer C2 beacon) ↔ **D3FEND D3-NTA** — confirm Suricata `fast.log` fires.

## What the exam asks
- **IDS vs IPS** is the core distinction: IDS = passive, out-of-band (mirror/tap), *alerts only*; IPS = inline, in the data path, can `drop`/`reject` — prevention at the cost of being a failure point. A mirror can never block.
- Suricata is **signature/known-threat** driven — the **ruleset is the detection content** (ET Open + `suricata-update`); stale rules detect nothing. EVE JSON feeds the SIEM.
- **Zeek logs behavior, it doesn't block** — `conn/dns/http/ssl.log` are for hunting and enrichment. "Detect a novel beacon with no signature" → Zeek; "block a known exploit inline" → Suricata IPS.
- They're **complementary on the same tap**: Suricata for precision on known threats, Zeek for breadth/context. Zeek ≈ flow logs / NSM; Suricata ≈ Azure Firewall Premium IDPS.
