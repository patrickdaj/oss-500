# Infra Attack Simulation — fire ATT&CK at your detection stack *(beyond-blueprint)*

Domains 3–4 built the detection stack: **Falco** + **Tetragon** (runtime), **Suricata** (network IDS), **Wazuh** (SIEM). This track fires **real [MITRE ATT&CK](https://attack.mitre.org/) (reference) techniques** at that stack and confirms the matching alert fires — the clean offense↔defense pairing **ATT&CK ↔ [D3FEND](https://d3fend.mitre.org/) (reference)**.

## Tools
| Tool | Model | Best for | Runs |
|---|---|---|---|
| **[Atomic Red Team](https://github.com/redcanaryco/atomic-red-team)** | atomic tests — one technique, one command | precise "did T1611 alert?" checks | `Invoke-AtomicTest` / the shell atomics, in a throwaway pod/host |
| **[Caldera](https://github.com/mitre/caldera)** | autonomous adversary emulation (chains) | multi-step operations, ability-to-alert coverage | self-hosted server + agent, local |
| **[Stratus Red Team](https://github.com/DataDog/stratus-red-team)** | cloud-native TTPs (as detonations) | cloud/k8s technique coverage without a cloud bill | `stratus detonate`, local targets |

## Technique → detector map (what should catch what)
| ATT&CK | Attack (atomic) | D3FEND | Detector that should fire |
|---|---|---|---|
| **T1611** Escape to Host | container breakout attempt | `D3-CI` Container Isolation | **Falco** "Container Drift"/breakout rule, **Tetragon** |
| **T1059** Command & Scripting | spawn a shell in a container | `D3-PSA` | **Falco** "Terminal shell in container" |
| **T1046** Network Service Discovery | in-cluster port scan | `D3-NTA` | **Suricata** scan signatures |
| **T1071** App-Layer C2 | beacon to a listener | `D3-NTA` | **Suricata** / Zeek anomalous egress |
| **T1078** Valid Accounts | reuse creds against a service | `D3-UAC` | **Wazuh** auth-failure/-success correlation |

## Method (the four steps, infra flavor)
The four steps are defined canonically in [`purple-team.md`](purple-team.md); here in infra flavor:
1. **Build** — the detection stack is up from D3/D4 (`d3-runtime-detection`, `d4-network-detection`, `d4-siem-wazuh`).
2. **Name** — pick the ATT&CK technique + its D3FEND countermeasure (table).
3. **Fire** — run the atomic / Caldera ability / Stratus detonation **inside the local cluster or a throwaway VM only**. The offensive lab-infra pins targets to the local stack.
4. **Confirm** — the alert appears in Falco output / Suricata `fast.log` / the Wazuh dashboard within seconds. **No alert = the finding**: document the coverage gap and (optionally) write the Sigma/Falco rule that closes it, then re-fire.

## Honesty & safety
- Techniques that need root or `--privileged` run in a **disposable** pod/VM you destroy after — never your daily driver.
- Record executed vs. directions. "T1611 fired, Falco did **not** alert — rule gap in X" is a *good*, publishable result.
- Everything is local; Stratus is used specifically so cloud TTPs can be exercised **without a cloud account**.

## Standards
Offense: MITRE ATT&CK. Defense: MITRE D3FEND + the CIS-hardened baselines from D4. Governance: **[NIST CSF 2.0](https://www.nist.gov/cyberframework)** *Detect* & *Respond* — this track is literally exercising those functions.

## Self-check
1. For T1611, name the atomic you'd run, the Falco rule that should fire, and the D3FEND id it implements.
2. When Atomic vs. Caldera vs. Stratus — what does each cover that the others don't?
3. A technique fires and nothing alerts. Walk the four steps you take next.
