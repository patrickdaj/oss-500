# Spec: frameworks-and-standards

## ADDED Requirements

### Requirement: A standards spine mapped offense ↔ defense
The course SHALL map its content to authoritative standards as a first-class, visible spine: each control to a **defensive** standard and each validation to an **offensive** one — **ATT&CK ↔ D3FEND** (infra), **OWASP LLM Top 10 + ATLAS + NIST AI RMF** (AI), **NIST SP 800-207/207A + CISA ZTMM** (zero trust), **CIS Benchmarks + NIST CSF 2.0** (posture/governance) — while retaining the existing **SC-500** objective mapping as the exam anchor. References SHALL be real and verified; no invented control IDs.

#### Scenario: A control cites its standards, both sides
- **WHEN** a learner reads a control's note or its objective in the tracker
- **THEN** it names the defensive standard it implements (e.g., a D3FEND technique / CIS control) and, where an attack validates it, the offensive standard (ATT&CK/ATLAS technique)

#### Scenario: The mapping renders in study-hub
- **WHEN** the course is ingested
- **THEN** the standards mapping is carried in the notes and the tracker (e.g., a `standards:` field per objective where useful) so it renders in-app, and the SC-500 anchor mapping remains intact
