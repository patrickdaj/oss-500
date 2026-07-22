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

## Steps

### Part A — atomic, precise (`av-atomic`)
In a **disposable** pod, run one atomic at a time and watch the detector:
```bash
# T1059 — shell in a container (should trip Falco "Terminal shell in container")
kubectl exec -it throwaway -- /bin/sh -c 'echo T1059'
# T1611 — escape-to-host attempt (should trip Falco breakout / Tetragon)
# (use the Atomic Red Team test for T1611 inside the throwaway pod)
```
For each: **name** the ATT&CK id + D3FEND countermeasure, fire it, then confirm in `kubectl logs -n falco` / Tetragon.

### Part B — chains and cloud TTPs (`av-caldera-stratus`)
- **Caldera**: run the self-hosted server + a local agent; execute a short adversary profile (discovery → execution → C2 beacon). Confirm Suricata `fast.log` flags the scan/beacon and Wazuh correlates the chain.
- **Stratus Red Team**: `stratus detonate <k8s-technique>` for cloud-native TTPs — exercised locally, **no cloud account**.

## Verification
- Each technique produces its expected alert within seconds: Falco rule / Suricata signature / Wazuh dashboard event.
- Build a small **coverage table**: technique → fired? → detector. Every "no" is a documented gap.
- For at least one gap, write the closing **Sigma or Falco rule**, reload, and **re-fire** to show the loop closes.

## Teardown
```bash
kubectl delete pod throwaway
../lab-infra/offense/down.sh      # stop Caldera, clean Stratus state
```

## Honesty note
Record executed vs. directions. "T1611 fired; Falco did **not** alert — added rule X; re-fired; now alerts" is the ideal write-up: it proves the control *and* your ability to improve it.
