# Spec: offensive-validation

## ADDED Requirements

### Requirement: A purple-team capstone that proves the defenses
The course SHALL add a capstone domain, **"Prove It: Offensive Validation"** (beyond-blueprint), that red-teams the controls built in Domains 1–4 across three tracks — **AI** (garak / PyRIT / PortSwigger vs the NeMo-Guardrails gateway), **infra** (Atomic Red Team / Caldera / Stratus Red Team firing real ATT&CK techniques at the Falco/Tetragon/Suricata/Wazuh stack), and **ZTNA** (unauthorized-access attempts vs the brokers) — each attack run against the *local* lab stack only, with teardown, and results reported honestly (executed vs. directions, no fabricated findings).

#### Scenario: An attack confirms a detection fires
- **WHEN** a learner runs an infra validation lab
- **THEN** they execute a real ATT&CK technique against the running detection stack and confirm the corresponding Falco/Suricata/Wazuh alert fires (or document the gap) — proving the control, not just deploying it

#### Scenario: The AI guardrail is red-teamed
- **WHEN** a learner runs the AI validation lab
- **THEN** garak/PyRIT attack the same gateway Domain 3 built, and each finding maps to OWASP LLM Top 10 + ATLAS with reproduction — reusing the real garak-vs-Ollama evidence from the migrated modern-security-lab work

### Requirement: "Validate it" callouts throughout Domains 1–4
Relevant existing D1–D4 labs SHALL gain a short **"validate it"** callout linking the attack that proves that control, so validation is felt across the course, not only in the capstone.

#### Scenario: A defensive lab points to its validation
- **WHEN** a learner finishes a control lab that has a corresponding attack
- **THEN** the lab ends with a "validate it" pointer to the offensive lab and the ATT&CK/ATLAS technique it exercises
