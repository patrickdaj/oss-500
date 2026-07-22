# AI Red-Teaming — attack the guardrail you built *(beyond-blueprint)*

Domain 3 built an LLM gateway: Ollama behind **NeMo Guardrails** + an OPA policy layer (`d3-ai`). This track red-teams *that exact gateway* and maps every finding to the **[OWASP LLM Top 10 (2025)](https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/)** risk and its **[MITRE ATLAS](https://atlas.mitre.org/)** (reference) technique — so a jailbreak isn't just "it said a bad thing," it's `LLM01 Prompt Injection` ↔ `AML.T0051`, reproducible and reportable.

This track attacks the **chat/RAG guardrail** (does the model *say* something unsafe); its agentic counterpart [`d6-validate`](../6-agentic-zero-trust/d6-validate.md) attacks the **agent's tools, identity, and actions** (does the agent *do* something unsafe — fire a consequential tool, use a token beyond scope). Run both.

## Tools
| Tool | What it does | Runs |
|---|---|---|
| **[garak](https://github.com/NVIDIA/garak)** | LLM vulnerability scanner — dozens of probes (jailbreak, prompt injection, data leakage, toxicity) fired automatically | `pipx run garak` against the local gateway |
| **[PyRIT](https://github.com/Azure/PyRIT)** | Microsoft's automated risk-identification toolkit — multi-turn attack orchestration, scorers | pip, scripted attacks |
| **Burp / PortSwigger** | web-layer testing of the gateway's HTTP surface (auth, IDOR on the API in front of the model) | manual/interactive |

## The OWASP-LLM ↔ ATLAS map (what you're actually testing)
| OWASP LLM (2025) | Attack | ATLAS | The guardrail that should stop it |
|---|---|---|---|
| **LLM01** Prompt Injection | garak `dan`/`promptinject` probes | `AML.T0051` LLM Prompt Injection | NeMo input rails / jailbreak detection |
| **LLM02** Sensitive Info Disclosure | ask for system prompt / secrets | `AML.T0057` LLM Data Leakage | NeMo output rails / OPA redaction |
| **LLM06** Excessive Agency | coax tool/plugin misuse | `AML.T0053` LLM Plugin Compromise | OPA tool-authorization policy |
| **LLM09** Misinformation | toxicity / hallucination probes | `AML.T0048` External Harms | content-safety output rail |

## Method (the four steps, AI flavor)
The four steps are defined canonically in [`purple-team.md`](purple-team.md); here in AI flavor:
1. **Build** — the gateway is already up from `d3-ai`.
2. **Name** — pick the OWASP-LLM risk + ATLAS technique (table above).
3. **Fire** — run garak's matching probe / a PyRIT orchestrator **against `http://localhost:<gateway>`** — never a hosted model API.
4. **Confirm** — the guardrail blocks or sanitizes the response; garak reports the probe as *defended*. Where a probe **passes** (gets through), that's the finding: record it against the OWASP/ATLAS id and note the rail that's missing.

## Reused real evidence
The migrated `modern-security-lab` work already ran **garak against Ollama** and captured real pass/fail output; that evidence is reused here as the baseline "undefended model" so the delta the guardrail adds is measurable (undefended vs. NeMo-fronted). Honesty rule: that run is *executed* evidence; anything you haven't run yourself is labeled *directions*.

## Standards
Offense: OWASP LLM Top 10, MITRE ATLAS. Governance: **[NIST AI RMF](https://www.nist.gov/itl/ai-risk-management-framework)** *Measure* (you are measuring risk) and *Manage* (you remediate the gaps). Defensive counterpart: the D3 guardrail rails themselves.

## Self-check
1. Map a garak jailbreak pass to its OWASP-LLM id and ATLAS technique, and name the NeMo rail that should have caught it.
2. Why test the HTTP surface (Burp) *and* the model (garak) — what class of bug does each find that the other misses?
3. What's the value of the undefended-Ollama baseline when reporting the guardrail's effectiveness?
