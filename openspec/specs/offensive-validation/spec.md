# offensive-validation Specification

## Purpose

oss-500 never proved its defenses work — every lab ended at "deployed," never "attacked and caught." This capability adds a purple-team validation dimension that proves every control by attacking it: a beyond-blueprint capstone domain that red-teams the Domains 1–4 controls across AI, infra, and ZTNA tracks against the local lab stack only, plus lightweight "validate it" callouts woven through the existing defensive labs. Attacks run locally with teardown, and results are reported honestly (executed vs. directions, no fabricated findings).
## Requirements
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

### Requirement: The purple-team method is defined once and cross-linked wherever applied

The purple-team four-step method (Build the control → Name the technique → Fire it locally → Confirm the defense holds) SHALL have a single canonical definition in `domains/5-offensive-validation/purple-team.md`. Any other note that applies the method — including flavored restatements in the Domain 5 track notes and the beyond-blueprint `domains/6-agentic-zero-trust/d6-validate.md` — SHALL cross-link that canonical note rather than presenting the method as a standalone re-teach, so each restatement reads as reinforcement of one authoritative source.

#### Scenario: A validation note applying the method cross-links the canonical definition

- **WHEN** a note outside `purple-team.md` restates the four-step method to apply it to a surface (for example `d6-validate.md` in its "four steps, agent flavor" section)
- **THEN** that note contains a link back to `purple-team.md` as the canonical method, and its own restatement retains only its surface-specific flavor rather than teaching the four steps as if newly introduced

#### Scenario: The canonical method has exactly one authoritative definition

- **WHEN** a reader looks for the authoritative statement of the Build → Name → Fire → Confirm method (the diagram and the "document the gap" loop)
- **THEN** it is found in `purple-team.md` alone, and every other occurrence is a flavored restatement that references it rather than a competing canonical definition

### Requirement: AI-track validation labs reference the shipped offense scaffolding

The AI-track validation labs (`d5-ai-redteam` and `d6-validate`) SHALL reference the shipped `lab-infra/offense/` scaffolding — the PyRIT orchestrator skeleton and the garak generator config — as the starting point the learner extends, rather than sending the learner to a bare tool repository with no runnable starting artifact. Where a lab asks the learner to "script a multi-turn PyRIT orchestrator" or run garak against the local gateway, it SHALL point at the shipped skeleton/config and mark the tool documentation by necessity per the citation standard.

#### Scenario: The PyRIT task starts from shipped scaffolding

- **WHEN** a learner reaches the "script a multi-turn PyRIT orchestrator" step in `d5-ai-redteam` or `d6-validate`
- **THEN** the lab points at the shipped `lab-infra/offense/` PyRIT skeleton as the starting point to extend, not a bare GitHub link

#### Scenario: The garak task uses the shipped generator config

- **WHEN** a learner runs garak against the local gateway in an AI-track validation lab
- **THEN** the lab references the shipped `localhost-ollama.json` generator config, so the learner does not have to author the REST-generator JSON from scratch

