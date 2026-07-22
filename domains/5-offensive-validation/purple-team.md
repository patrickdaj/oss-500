# Prove It: Offensive Validation — the purple-team method *(beyond-blueprint)*

Every lab in Domains 1–4 ends at "deployed." This capstone domain asks the harder question: **does the control actually work?** A control you have never attacked is a hypothesis, not a defense. Here you prove each one by attacking it — the *purple* discipline: red-team actions run against your own blue-team stack, with the goal of **confirming detection and enforcement**, not scoring a win.

> **Beyond-blueprint.** SC-500 is a defensive exam; it does not ask you to run attacks. This domain is expanded, portfolio-grade enrichment — it's what turns "I deployed Falco" into "I fired T1611 and watched Falco catch it." Domains 1–4 keep their exam mapping intact.

## The method — four steps, every time

```
   ┌──────────────┐   ┌──────────────────┐   ┌────────────┐   ┌────────────────────┐
   │ 1. Build the │   │ 2. Name the      │   │ 3. Fire it │   │ 4. Confirm the     │
   │    control   │──▶│    technique     │──▶│  (locally) │──▶│    defense holds   │
   │ (D1–D4 lab)  │   │ ATT&CK / ATLAS   │   │            │   │  alert fires / deny │
   └──────────────┘   └──────────────────┘   └────────────┘   └────────────────────┘
          │                                                            │
          └──────────────── if it doesn't hold: document the gap ──────┘
```

1. **Build the control** — it already exists from Domains 1–4 (a Falco rule, a NetworkPolicy, a guardrail, a broker).
2. **Name the technique** — the specific [ATT&CK](https://attack.mitre.org/) (reference) (infra) or [ATLAS](https://atlas.mitre.org/) (reference) / [OWASP LLM Top 10](https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/) (AI) technique that attacks it. Naming it is what makes the test repeatable and the report legible.
3. **Fire it** — run the technique **against the local lab stack only**. Never an external target. Tear down after.
4. **Confirm** — the corresponding alert fires / the request is denied. If it doesn't, that's the finding: **document the gap** honestly (a missing rule, a mis-scoped policy) rather than hiding it.

## The three tracks

| Track | Attack tools | Targets (built in) | Frameworks | Lab |
|---|---|---|---|---|
| **AI** | garak, PyRIT, Burp/PortSwigger | the NeMo-Guardrails gateway (D3 `d3-ai`) | OWASP LLM Top 10 ↔ ATLAS | [`../../labs/d5-ai-redteam.md`](../../labs/d5-ai-redteam.md) |
| **Infra** | Atomic Red Team, Caldera, Stratus Red Team | Falco / Tetragon / Suricata / Wazuh (D3/D4) | ATT&CK ↔ D3FEND | [`../../labs/d5-infra-attack-simulation.md`](../../labs/d5-infra-attack-simulation.md) |
| **ZTNA** | curl / ssh / direct-dial bypass attempts | the brokers (D1 `d1-ztna`) | NIST 800-207 authz | [`../../labs/d5-ztna-authz.md`](../../labs/d5-ztna-authz.md) |

Each track has its own note: [AI red-teaming](ai-redteam.md), [infra attack simulation](infra-attack-simulation.md), [ZTNA authz testing](ztna-authz.md).

## Rules of engagement (non-negotiable)
- **Local only.** Every attack targets the local kind/Compose stack you built. No external hosts, no shared infrastructure, ever — the offensive lab-infra ([`../../lab-infra/offense/`](../../lab-infra/offense/)) is wired to `127.0.0.1`/in-cluster targets by design.
- **Honesty over spectacle.** Report what was *executed* vs. what is *directions-only*, and record real results — including "the alert did **not** fire." Fabricated findings are worse than none. (See the honesty discipline in [`../standards-map.md`](../standards-map.md).)
- **Teardown is part of the lab.** Attack tooling comes down with the target; documented in each lab.

## Why this is the payoff
Blue teams that never get attacked drift: rules rot, policies over-grant, guardrails regress. Pairing every control with the technique that tests it — and re-running it — is what **continuous validation** (NIST CSF *Detect*/*Respond*, CISA ZTMM "continually verify") looks like in practice. It's also what a hiring manager wants to see: not a list of tools installed, but evidence you can **prove** a defense works and **name** the exact adversary behavior it stops.

## Self-check
1. Give the four steps of the method for a single control of your choice, naming a real ATT&CK/ATLAS technique in step 2.
2. Why is "the alert did not fire" a *successful* lab outcome, not a failure?
3. What single rule makes this domain safe to run on a laptop, and why does it matter legally as well as technically?
