# Standards Map — the spine

This course is standards-grounded, not tool-driven. Every control cites a **defensive** standard; every validation (the purple-team labs) cites an **offensive** one. The pairing is the point — build the control, name the technique that attacks it, fire it, confirm the defense holds.

## The offense ↔ defense pairing

Every link in this table is a **canonical reference** — the framework's home cited for provenance and lookup, not required reading — so each is marked `(reference)` per [How resources are cited](#how-resources-are-cited).

| Area | Offensive (attack) | Defensive (control) | Governance |
|---|---|---|---|
| **Infra / cloud-native** | [MITRE ATT&CK](https://attack.mitre.org/) (reference — techniques) | [MITRE D3FEND](https://d3fend.mitre.org/) (reference — countermeasures) + [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks) (reference — hardening) | [NIST CSF 2.0](https://www.nist.gov/cyberframework) (reference) |
| **AI** | [MITRE ATLAS](https://atlas.mitre.org/) (reference — techniques) + [OWASP LLM Top 10 (2025)](https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/) (reference — risks) | content-safety / guardrails (the D3 defenses) | [NIST AI RMF](https://www.nist.gov/itl/ai-risk-management-framework) (reference — Govern/Map/Measure/Manage) |
| **Zero trust** | authz bypass attempts (the ZTNA validation labs) | [NIST SP 800-207](https://csrc.nist.gov/pubs/sp/800/207/final) (reference) / [800-207A](https://csrc.nist.gov/pubs/sp/800/207/a/final) (reference) | [CISA ZTMM v2.0](https://www.cisa.gov/zero-trust-maturity-model) (reference — maturity) |
| **Exam anchor** | — | **SC-500** objective mapping (the `sc500` field per objective) | — |

## How it's carried
- **Notes** state the standards inline where a control or attack is taught.
- **Tracker** — objectives may carry a `standards:` field (defensive + offensive refs) alongside the existing `oss` (the tool) and `sc500` (the exam control). It renders as a column in `assessment/tracker.md`.
- **Convention:** cite the specific technique/control where it's meaningful (e.g. `ATT&CK T1611` ↔ `D3FEND D3-CI`, `OWASP LLM01` ↔ `ATLAS AML.T0051`), not just the framework name. Real, verified IDs only — never invented.

## The through-line
ATT&CK/ATLAS name *how an adversary acts*; D3FEND/CIS/guardrails name *what you build*; NIST CSF/AI RMF/CISA ZTMM name *how you govern and mature it*; SC-500 keeps the exam honest. A learner should be able to point at any lab and say which standard it implements and which technique proves it.

## How resources are cited
This curriculum's job is to say **exactly** what to read or watch — and no more. Every external link a note or lab points you at is a claim on your time; a link to a whole doc site wastes it. So resources follow one convention.

**Format** — a learning resource is cited as:

```
- [Resource — the specific thing](deep-url#anchor) (~NN min[, §range])
```

- **Deep-link + name the target.** The URL points at the exact page/section/anchor (`#anchor` when the page supports it), and the link text names the heading, chapter, or section to read — so you know what to open *without* clicking. A bare homepage or a `…/docs/` root is not a learning resource; it's a wild-goose chase.
- **State the range when only part is needed.** For a long page, book, or video, cite the bounded slice: sections (`§4–7`), chapters/pages (`ch. 2–3`), or video timestamps (`12:00–24:00`). Never cite a whole video — always the timestamp range to watch.
- **Scope the time estimate.** `(~NN min)` covers *only* the cited slice, not the whole resource. When you narrow a citation to a range, narrow the estimate to match.
- **Inline/prose links** follow the same rule: the sentence names what to read at the other end.

**`(reference)` — the escape hatch.** A link cited for *lookup or provenance* rather than required reading — a tool's home page, a framework's site, an API index, a spec's canonical URL — is marked `(reference)` (optionally `(reference — <scope>)`). This keeps homepage links honest: they're allowed *because* they're flagged as non-required. Use it only for genuine navigational/canonical references, never to dodge deep-linking a resource a learner must actually read.

**Enforcement.** `npm run lint:content` (study-hub) and the repo-side `scripts/lint-links.mjs` (oss-500 CI) fail on a host-only or documentation-root link in `domains/**` or `labs/**` that isn't marked `(reference)`. The standard is checked, not just intended.
