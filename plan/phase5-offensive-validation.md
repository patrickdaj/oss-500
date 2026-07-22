# Phase 5 — Offensive validation

Domain 5 is **beyond-blueprint** — it carries no SC-500 exam weight, because SC-500 is a defensive exam that never asks you to run attacks. This phase is the payoff of Domains 1–4: a control you have never attacked is a hypothesis, not a defense. Here you prove each one the **purple** way — fire the exact adversary technique at your own blue-team stack and confirm the alert fires or the request is denied. By its checkpoint you should be able to name a technique in ATT&CK/ATLAS, fire it *locally*, and show the matching Falco/Suricata/Wazuh alert or broker denial — and, just as valuably, document honestly when a control **doesn't** hold.

Notes live in [`domains/5-offensive-validation/`](../domains/5-offensive-validation/); labs in [`labs/`](../labs/); attack tooling and pinned local targets in [`lab-infra/offense/`](../lab-infra/offense/). **Rule of engagement, non-negotiable:** every attack targets the local kind/Compose stack you already built — never an external host, ever. Privileged techniques run in a disposable pod/VM you destroy after; teardown of the attack tooling is part of every lab.

## Day 1 — The purple-team method (name → fire → confirm)

- [ ] **[1.5h] Read the method** — [purple-team.md](../domains/5-offensive-validation/purple-team.md) (`pt-method`): the four steps (build the control → name the ATT&CK/ATLAS technique → fire it locally → confirm the defense holds), the three tracks (AI / infra / ZTNA), and the rules of engagement. This loop frames every later day.
- [ ] **[1h] Internalize "the alert did not fire = a finding"** — write, in your own words, why a non-firing detection is a *successful, publishable* result and how you'd document the gap (missing rule, mis-scoped policy) rather than hide it. This honesty discipline is the whole domain's ethic.
- [ ] **[1h] Confirm the offense lab-infra targets local only** — inspect [`lab-infra/offense/`](../lab-infra/offense/): the attack tooling is wired to `127.0.0.1`/in-cluster targets by design. Verify your Phase 3/4 detection stacks (Falco/Tetragon, Suricata, Wazuh) are reachable as the *targets* you'll fire at this week.
- [ ] **[0.5h] Quiz + note** — attempt `q5-01`–`q5-03` from [quiz-5](../assessment/data/quiz-5.yaml); note the four steps against one control of your choice, naming a real technique in step 2.

## Day 2 — AI red-teaming (garak, PyRIT)

- [ ] **[2h] Read AI red-teaming notes** — [ai-redteam.md](../domains/5-offensive-validation/ai-redteam.md) (`av-ai-garak`, `av-ai-pyrit`): the OWASP-LLM ↔ ATLAS map, garak's automated probes vs. PyRIT's multi-turn orchestration, and why the undefended-Ollama baseline makes the guardrail's value measurable. Map to attacking the D3 NeMo-Guardrails gateway.
- [ ] **[2h] Lab — fire garak at the guardrail** — [d5-ai-redteam](../labs/d5-ai-redteam.md): bring the D3 gateway up, run garak's jailbreak/promptinject probes against `http://localhost:<gateway>`, and map each result to its OWASP-LLM id + ATLAS technique. **Observable: garak surfaces a jailbreak the guardrail missed — you name the missing NeMo rail, add it, and re-run until the probe reports *defended*.**
- [ ] **[1.5h] Lab — PyRIT multi-turn + the HTTP surface** — script a PyRIT orchestration that builds an attack across turns; separately test the gateway's HTTP surface (auth/IDOR) so you see the bug class Burp finds that garak misses. Record executed vs. directions.
- [ ] **[0.5h] Quiz** — `q5-04`–`q5-08` (AI red-teaming). Note any misses for the flex day.

## Day 3 — Infra attack simulation (Atomic, Caldera, Stratus)

- [ ] **[2h] Read infra attack-sim notes** — [infra-attack-simulation.md](../domains/5-offensive-validation/infra-attack-simulation.md) (`av-atomic`, `av-caldera-stratus`): the ATT&CK → detector map (T1611→Falco, T1059→Falco shell, T1046→Suricata, T1078→Wazuh), and when to reach for Atomic (one technique) vs. Caldera (chained operations) vs. Stratus (cloud TTPs, no cloud account).
- [ ] **[2.5h] Lab — fire ATT&CK atomics at the Phase 4 stack** — [d5-infra-attack-simulation](../labs/d5-infra-attack-simulation.md): run a container-breakout atomic (T1611) in a disposable pod and confirm Falco/Tetragon alerts; fire an in-cluster port scan (T1046) and confirm Suricata. **Observable: each fired technique produces its matching alert within seconds — or the *absence* of one is the finding you document (and optionally close with a new Sigma/Falco rule, then re-fire).**
- [ ] **[1h] Chained + cloud coverage** — run a short Caldera operation for ability-to-alert coverage across a path, and a Stratus detonation for a cloud-native TTP without a cloud bill. Tear all attack tooling and disposable targets down.
- [ ] **[0.5h] Quiz** — `q5-09`–`q5-13` (infra). 

## Day 4 — ZTNA authorization testing (prove least privilege denies)

> **Prerequisite.** These attacks need the ZTNA brokers **already deployed and reachable** — they are built in [Phase 1 → Day 6, "ZTNA access brokers"](phase1-identity-governance.md). Re-stand-up the `lab-infra/ztna-*` broker(s) you're testing (Boundary+Vault, OpenZiti, Pomerium, NetBird) before firing; a broker that isn't up can't prove a deny.

- [ ] **[2h] Read ZTNA authz notes** — [ztna-authz.md](../domains/5-offensive-validation/ztna-authz.md) (`av-ztna-authz`): the per-model negative tests (Boundary+Vault, OpenZiti, Pomerium, NetBird), why an over-granted policy is more dangerous than an outage, and why only the negative test surfaces it.
- [ ] **[2.5h] Lab — attack each broker, confirm the deny** — [d5-ztna-authz](../labs/d5-ztna-authz.md) against the D1 `d1-ztna` brokers: attempt access you are not authorized for and reach the host directly, bypassing the broker. **Observable: access is *denied* and there is no standing network route — the dial refuses, the underlay shows no listening port, or the request 302→IdP then 403.**
- [ ] **[1h] Close the loop into the SIEM** — wire a broker session-denied event into the D4 Wazuh SIEM so the refusal is not just enforced but *alertable* (attack → deny → alert). Tear down.
- [ ] **[0.5h] Quiz** — `q5-14`–`q5-19` (ZTNA + method). Note misses for the flex day.

## Day 5 — Synthesis, flex, and Checkpoint 5

- [ ] **[1.5h] Catch-up / slippage** — finish any unrun attack (walkthrough a technique at depth if a host constraint blocked firing it). Slippage from Days 1–4 lands here, not in Phase 6.
- [ ] **[1h] Confirm every lab's proof-of-work observable** — for each d5 lab, restate the technique you fired and the detection/denial you confirmed (or the gap you documented and closed). Filter the tracker for `d5` confidence < 2.
- [ ] **[1h] Full teardown check** — confirm all offense tooling and disposable targets are down; `kubectl get all -A -l app.kubernetes.io/part-of=oss500` and `docker compose -p oss500 ps` reflect only the stacks you mean to keep.
- [ ] **Rest** — take your day off this week before Phase 6.

## Checkpoint

Take **[checkpoint-5](../assessment/checkpoint-5.md)** (bank: [quiz-5](../assessment/data/quiz-5.yaml), pass ≥ 80%) in test mode on this synthesis day. Every d5 subsection is represented — the purple-team method, AI red-teaming (garak/PyRIT), infra attack simulation (Atomic/Caldera/Stratus), and ZTNA authorization testing.

- Score **< 80%** → this day's remaining time goes to remediation: each missed question maps to `objectiveIds`; re-read that note section and re-run its attack (fire the technique again — don't just re-read) before moving on.
- Score **≥ 80%** with every d5 objective at confidence ≥ 2 → Domain 5 is green. Proceed to [Phase 6 — Agentic zero trust](phase6-agentic-zero-trust.md).

> **Beyond-blueprint note.** Domain 5 carries no SC-500 weight — it is portfolio-grade enrichment — but [gates on its checkpoint exactly as the SC-500 phases do](overview.md#phase-map). Proof-of-work (the technique fires, the control holds) is the per-lab observable.
