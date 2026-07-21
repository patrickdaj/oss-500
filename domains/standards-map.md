# Standards Map — the spine

This course is standards-grounded, not tool-driven. Every control cites a **defensive** standard; every validation (the purple-team labs) cites an **offensive** one. The pairing is the point — build the control, name the technique that attacks it, fire it, confirm the defense holds.

## The offense ↔ defense pairing

| Area | Offensive (attack) | Defensive (control) | Governance |
|---|---|---|---|
| **Infra / cloud-native** | [MITRE ATT&CK](https://attack.mitre.org/) (techniques) | [MITRE D3FEND](https://d3fend.mitre.org/) (countermeasures) + [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks) (hardening) | [NIST CSF 2.0](https://www.nist.gov/cyberframework) |
| **AI** | [MITRE ATLAS](https://atlas.mitre.org/) (techniques) + [OWASP LLM Top 10 (2025)](https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/) (risks) | content-safety / guardrails (the D3 defenses) | [NIST AI RMF](https://www.nist.gov/itl/ai-risk-management-framework) (Govern/Map/Measure/Manage) |
| **Zero trust** | authz bypass attempts (the ZTNA validation labs) | [NIST SP 800-207](https://csrc.nist.gov/pubs/sp/800/207/final) / [800-207A](https://csrc.nist.gov/pubs/sp/800/207/a/final) | [CISA ZTMM v2.0](https://www.cisa.gov/zero-trust-maturity-model) (maturity) |
| **Exam anchor** | — | **SC-500** objective mapping (the `sc500` field per objective) | — |

## How it's carried
- **Notes** state the standards inline where a control or attack is taught.
- **Tracker** — objectives may carry a `standards:` field (defensive + offensive refs) alongside the existing `oss` (the tool) and `sc500` (the exam control). It renders as a column in `assessment/tracker.md`.
- **Convention:** cite the specific technique/control where it's meaningful (e.g. `ATT&CK T1611` ↔ `D3FEND D3-CI`, `OWASP LLM01` ↔ `ATLAS AML.T0051`), not just the framework name. Real, verified IDs only — never invented.

## The through-line
ATT&CK/ATLAS name *how an adversary acts*; D3FEND/CIS/guardrails name *what you build*; NIST CSF/AI RMF/CISA ZTMM name *how you govern and mature it*; SC-500 keeps the exam honest. A learner should be able to point at any lab and say which standard it implements and which technique proves it.
