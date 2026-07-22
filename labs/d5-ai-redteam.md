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

## Challenge
Attack the **exact LLM gateway** Domain 3 built — Ollama fronted by NeMo Guardrails + OPA (`d3-ai`) — with garak and PyRIT, then map every finding to **OWASP LLM Top 10 + MITRE ATLAS**.

The **expected control response**: a garak probe (jailbreak/DAN-style, prompt injection, training-data leak) that gets through an **undefended** Ollama should be **blocked or narrowed** once the identical probe hits the **guardrailed** gateway — the rails earn their keep by measurably shrinking the attack surface. A PyRIT multi-turn orchestrator should surface system-prompt disclosure that single-shot garak misses (or confirm the rails hold under escalation). The gateway's **HTTP** surface (auth, IDOR on session/conversation ids) needs its own pass — a perfectly guarded model sitting behind an unguarded API is still broken.

Where a probe **passes** the guardrail, that is the finding: name the OWASP-LLM id and ATLAS technique and write it up honestly instead of papering over the gap. No tooling commands or probe lists here — you pick and fire them yourself in the next section.

## Build it (guided)

### Part A — baseline the undefended model (`av-ai-garak`)
Point garak at **Ollama directly** (no guardrail) to establish what an unprotected model leaks. **Your turn**: pick a small set of garak probes that together cover a jailbreak/DAN-style probe, a prompt-injection probe, and a training-data-leak probe — check garak's probe catalog (`garak --list_probes`) rather than guessing names — and fire them at the raw endpoint. Record which probes **pass** (get through). That's your baseline attack surface. (This baseline can reuse the garak-vs-Ollama evidence migrated from `modern-security-lab`; if you run it yourself instead, label it *executed*.)

### Part B — fire the identical probes at the guardrailed gateway
Re-point garak at the **NeMo-fronted** gateway and re-run the **same** probe set you chose in Part A — same probes, same order, so the comparison is apples-to-apples. For each result:
1. **Name** the OWASP-LLM id + ATLAS technique yourself (e.g. a DAN-style pass is a prompt-injection/jailbreak technique — work the exact ids out from the OWASP LLM Top 10 and the ATLAS matrix rather than guessing).
2. Compare defended vs. baseline — the delta is what the guardrail bought you. Where the delta is zero (a probe still passes), that's a gap to write up, not hide.

### Part C — multi-turn + web surface (`av-ai-pyrit`)
- **PyRIT**: script a multi-turn orchestrator that escalates toward system-prompt disclosure. Multi-turn finds what single-shot garak misses — design your own escalation path (start benign, layer social-engineering/role-play turns across multiple calls, and watch for the rails to hold or slip). Name the OWASP-LLM id + ATLAS technique for whatever you find.
- **Burp/PortSwigger**: test the gateway's **HTTP** surface yourself — auth on the API, IDOR on any conversation/session id. The model can be perfectly guarded while the API in front of it isn't.

## Verification
- Each garak probe that the gateway **defends** is reported as such; each that **passes** is logged against its OWASP/ATLAS id with a reproduction.
- The defended-vs-baseline table shows the rails measurably reducing successful probes.
- Any gap (a probe that passes the guardrail) is written up with the missing rail named — **not** hidden.

## Reference solution
Build it yourself first; check after.

**Tooling.** Install garak + PyRIT from [`../lab-infra/offense/`](../lab-infra/offense/) (`./up.sh` — isolated venv, refuses any non-local `TARGET_HOST`):
```bash
# Part A — baseline against raw Ollama (no guardrail)
pipx run garak --model_type rest -G localhost-ollama.json --probes dan,promptinject,leakreplay

# Part B — identical probes against the NeMo-fronted gateway
pipx run garak --model_type rest -G <gateway-config>.json --probes dan,promptinject,leakreplay
```
The baseline row can reuse the garak-vs-Ollama evidence migrated from `modern-security-lab`; the guardrailed row is what you run yourself against `d3-ai`.

**Attack ↔ technique map** (OWASP LLM Top 10 ↔ MITRE ATLAS), from the Standards line above:

| Probe / attack | OWASP LLM Top 10 | ATLAS technique |
|---|---|---|
| garak `dan` (jailbreak pass) | LLM01 — Prompt Injection | AML.T0051 |
| garak `promptinject` | LLM01 — Prompt Injection | AML.T0051 |
| garak `leakreplay` (training-data leak) | LLM06 — Sensitive Information Disclosure | AML.T0053 |
| PyRIT multi-turn → system-prompt disclosure | LLM02 ↔ sensitive/system-prompt disclosure | AML.T0057 |

Defensive counterpart for every row above: the NeMo rails + OPA policy built in `d3-ai`.

## Teardown
```bash
../lab-infra/offense/down.sh     # removes venvs/reports
# stop the d3-ai gateway per its lab
```

## Honesty note
The undefended-Ollama run is **executed** evidence (reused from modern). Label anything you personally did not run as *directions*. "The guardrail let `promptinject` through — output rail X missing" is a valid, valuable result.
