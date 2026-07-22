# Lab d5: Infra Attack Simulation *(beyond-blueprint)*

Fire **real MITRE ATT&CK techniques** at the detection stack you built in Domains 3–4 (Falco, Tetragon, Suricata, Wazuh) with Atomic Red Team, Caldera, and Stratus — and confirm the matching alert fires, or document the gap.

**Objectives covered**

| id | Objective |
|---|---|
| `av-atomic` | Fire atomic techniques (T1611, T1059) at Falco/Tetragon; confirm the rule fires |
| `av-caldera-stratus` | Adversary-emulation chains (Caldera) + cloud-native detonations (Stratus) vs Suricata/Wazuh |

**SC-500 correspondence**: beyond SC-500. **Standards**: ATT&CK ↔ D3FEND (T1611↔D3-CI, T1059↔D3-PSA, T1046/T1071↔D3-NTA), NIST CSF *Detect/Respond*. Defensive counterpart: the D3/D4 detection rules.

**Prerequisites**
- The detection stack up: [`d3-runtime-detection`](d3-runtime-detection.md) (Falco/Tetragon), [`d4-network-detection`](d4-network-detection.md) (Suricata), [`d4-siem-wazuh`](d4-siem-wazuh.md) (Wazuh). Offense tooling from [`../lab-infra/offense/`](../lab-infra/offense/).
- Notes read: [`../domains/5-offensive-validation/infra-attack-simulation.md`](../domains/5-offensive-validation/infra-attack-simulation.md).

**Estimated time**: 3–4 h · $0 (local) · **disposable targets only**

> **Local, disposable only.** Privileged techniques run in a throwaway pod/VM you destroy after — never your daily driver, never an external host.

## Challenge

Two threat-response pairs to prove, both fired at the stack you built in Domains 3–4. No solution here — the observable is what you're aiming at, not how to get there.

- **Atomic, precise** (`av-atomic`) — one technique, one command, in a **disposable** pod: T1059 (spawn a shell in a container) or T1611 (an escape-to-host attempt). The matching Falco rule (or Tetragon) must alert within seconds of the fire. No alert isn't a failure to hide — it's the finding you write up.
- **Chains and cloud TTPs** (`av-caldera-stratus`) — a short Caldera adversary-emulation chain (discovery → execution → C2 beacon) run locally, plus a Stratus Red Team cloud-native detonation with no cloud account. Suricata's `fast.log` must flag the scan/beacon, and Wazuh must correlate the multi-step chain into a single view.

Reach: a coverage table (technique → fired? → detector) with every "no" documented as a gap, and for at least one gap, a closing Sigma/Falco rule that you reload and re-fire against.

## Build it (guided)

### Part A — atomic, precise (`av-atomic`)
1. In a **disposable** pod, pick one technique from the objectives table above: T1059 or T1611.
2. **Name it before you fire it** — the ATT&CK id and the D3FEND countermeasure it maps to. Why: naming first forces a prediction of which detector should catch it, so a miss reads as a legible gap instead of a shrug.
3. Fire it — a shell command for T1059, an Atomic Red Team test for T1611 — inside the throwaway pod only. Pick the exact command/test yourself; the reference solution has one worked example if you get stuck.
4. Confirm in the detector's own output (`kubectl logs -n falco` / Tetragon): does the expected rule name appear within seconds?
5. Your turn: record the exact command you ran and the exact log line that did (or didn't) fire.

### Part B — chains and cloud TTPs (`av-caldera-stratus`)
1. Stand up Caldera self-hosted (server + one local agent).
2. Design a short adversary profile yourself: discovery → execution → C2 beacon. Why this shape: it mirrors a real intrusion's kill chain, so a single Suricata/Wazuh miss anywhere breaks coverage for the whole chain, not just one step.
3. Run the profile, then confirm Suricata's `fast.log` flags the scan/beacon and Wazuh correlates the chain into one incident view.
4. Separately, run one Stratus Red Team detonation (`stratus detonate <k8s-technique>`) for a cloud-native TTP — local only, no cloud account — and confirm its expected detector fires.
5. Your turn: build the coverage table called out in Verification below, and for one "no," write and reload the closing rule.

## Verification
- Each technique produces its expected alert within seconds: Falco rule / Suricata signature / Wazuh dashboard event.
- Build a small **coverage table**: technique → fired? → detector. Every "no" is a documented gap.
- For at least one gap, write the closing **Sigma or Falco rule**, reload, and **re-fire** to show the loop closes.

## Reference solution
Build it yourself first; check after.

Tooling commands — from [`../lab-infra/offense/`](../lab-infra/offense/) (`up.sh` prints the infra-tool setup; verbatim below):
```bash
# Atomic Red Team — clone, run atomics INSIDE a disposable pod/VM only
git clone https://github.com/redcanaryco/atomic-red-team

# T1059 — shell in a container (should trip Falco "Terminal shell in container")
kubectl exec -it throwaway -- /bin/sh -c 'echo T1059'
# T1611 — escape-to-host attempt (should trip Falco breakout rule / Tetragon)
# (use the Atomic Red Team test for T1611 inside the throwaway pod)

# Caldera — self-hosted server + local agent
git clone https://github.com/mitre/caldera --recursive
python3 server.py --insecure   # localhost only

# Stratus Red Team — single binary, local targets only
stratus detonate <k8s-technique>
```

Technique → detector map (ATT&CK ↔ D3FEND), from [`../domains/5-offensive-validation/infra-attack-simulation.md`](../domains/5-offensive-validation/infra-attack-simulation.md):

| ATT&CK | Attack (atomic) | D3FEND | Detector that should fire |
|---|---|---|---|
| **T1611** Escape to Host | container breakout attempt | `D3-CI` Container Isolation | **Falco** "Container Drift"/breakout rule, **Tetragon** |
| **T1059** Command & Scripting | spawn a shell in a container | `D3-PSA` | **Falco** "Terminal shell in container" |
| **T1046** Network Service Discovery | in-cluster port scan | `D3-NTA` | **Suricata** scan signatures |
| **T1071** App-Layer C2 | beacon to a listener | `D3-NTA` | **Suricata** / Zeek anomalous egress |
| **T1078** Valid Accounts | reuse creds against a service | `D3-UAC` | **Wazuh** auth-failure/-success correlation |

If a technique fires and nothing alerts, don't just note the gap — write the closing Sigma/Falco rule, reload the ruleset, and re-fire per Verification, then flip that row of your coverage table from "no" to "closed."

## Teardown
```bash
kubectl delete pod throwaway
../lab-infra/offense/down.sh      # stop Caldera, clean Stratus state
```

## Honesty note
Record executed vs. directions. "T1611 fired; Falco did **not** alert — added rule X; re-fired; now alerts" is the ideal write-up: it proves the control *and* your ability to improve it.
