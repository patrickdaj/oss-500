# Lab d5: AI Red-Teaming the Guardrail *(beyond-blueprint)*

Attack the **exact LLM gateway** Domain 3 built (Ollama behind NeMo Guardrails + OPA, `d3-ai`) with garak and PyRIT, and map every finding to **OWASP LLM Top 10 + MITRE ATLAS**. Prove the guardrail blocks what it should — and record honestly where it doesn't.

**Objectives covered**

| id | Objective |
|---|---|
| `av-ai-garak` | Scan the gateway with garak; map findings to OWASP LLM Top 10 + ATLAS |
| `av-ai-pyrit` | Multi-turn (PyRIT) + web-surface (Burp) attacks against the gateway |

**SC-500 correspondence**: beyond SC-500 (defensive exam). **Standards**: OWASP LLM01/02/06, MITRE ATLAS (AML.T0051/T0053/T0057), NIST AI RMF *Measure/Manage*. Defensive counterpart: the NeMo rails + OPA from `d3-ai`.

**Prerequisites**
- The `d3-ai` gateway running locally ([`d3-ai-security`](d3-ai-security.md)); `pipx`/`python3`; offense tooling from [`../lab-infra/offense/`](../lab-infra/offense/).
- Notes read: [`../domains/5-offensive-validation/purple-team.md`](../domains/5-offensive-validation/purple-team.md), [`ai-redteam.md`](../domains/5-offensive-validation/ai-redteam.md).

**Estimated time**: 2–3 h · $0 (local) · **local target only**

> **Local only.** Point every tool at `http://localhost:<gateway-port>` — never a hosted model API.

## Steps

### Part A — baseline the undefended model (`av-ai-garak`)
Run garak against **Ollama directly** (no guardrail) to establish what an unprotected model leaks — this reuses the real garak-vs-Ollama evidence migrated from `modern-security-lab`:
```bash
pipx run garak --model_type rest -G localhost-ollama.json --probes dan,promptinject,leakreplay
```
Record which probes **pass** (get through). That's your baseline attack surface.

### Part B — fire the same probes at the guardrailed gateway
Re-point garak at the **NeMo-fronted** endpoint and re-run the identical probes. For each result:
1. **Name** the OWASP-LLM id + ATLAS technique (e.g. a DAN pass = `LLM01` ↔ `AML.T0051`).
2. Compare defended vs. baseline — the delta is what the guardrail bought you.

### Part C — multi-turn + web surface (`av-ai-pyrit`)
- **PyRIT**: script a multi-turn orchestrator that escalates toward system-prompt disclosure (`LLM02` ↔ `AML.T0057`). Multi-turn finds what single-shot garak misses.
- **Burp/PortSwigger**: test the gateway's **HTTP** surface — auth on the API, IDOR on any conversation/session id. The model can be perfectly guarded while the API in front of it isn't.

## Verification
- Each garak probe that the gateway **defends** is reported as such; each that **passes** is logged against its OWASP/ATLAS id with a reproduction.
- The defended-vs-baseline table shows the rails measurably reducing successful probes.
- Any gap (a probe that passes the guardrail) is written up with the missing rail named — **not** hidden.

## Teardown
```bash
../lab-infra/offense/down.sh     # removes venvs/reports
# stop the d3-ai gateway per its lab
```

## Honesty note
The undefended-Ollama run is **executed** evidence (reused from modern). Label anything you personally did not run as *directions*. "The guardrail let `promptinject` through — output rail X missing" is a valid, valuable result.
