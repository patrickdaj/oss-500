# Standards Map — the spine

This course is standards-grounded, not tool-driven. Every control cites a **defensive** standard; every validation (the purple-team labs) cites an **offensive** one. The pairing is the point — build the control, name the technique that attacks it, fire it, confirm the defense holds.

## The offense ↔ defense pairing

Every link in this table is a **canonical reference** — the framework's home cited for provenance and lookup, not required reading — so each is marked `(reference)` per [How resources are cited](#how-resources-are-cited).

| Area | Offensive (attack) | Defensive (control) | Governance |
|---|---|---|---|
| **Infra / cloud-native** | [MITRE ATT&CK](https://attack.mitre.org/) (reference — techniques) | [MITRE D3FEND](https://d3fend.mitre.org/) (reference — countermeasures) + [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks) (reference — hardening) | [NIST CSF 2.0](https://www.nist.gov/cyberframework) (reference) |
| **AI** | [MITRE ATLAS](https://atlas.mitre.org/) (reference — techniques) + [OWASP LLM Top 10 (2025)](https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/) (reference — risks) | content-safety / guardrails (the D3 defenses) | [NIST AI RMF](https://www.nist.gov/itl/ai-risk-management-framework) (reference — Govern/Map/Measure/Manage) |
| **Zero trust** | authz bypass attempts (the ZTNA validation labs) | [NIST SP 800-207](https://csrc.nist.gov/pubs/sp/800/207/final) (reference) / [800-207A](https://csrc.nist.gov/pubs/sp/800/207/a/final) (reference) | [CISA ZTMM v2.0](https://www.cisa.gov/zero-trust-maturity-model) (reference — maturity) |
| **Agentic** *(beyond-blueprint, D6)* | [MITRE ATLAS](https://atlas.mitre.org/) `AML.T0053` (reference — AI Agent Tool Invocation) + [OWASP Agentic AI](https://genai.owasp.org/resource/agentic-ai-threats-and-mitigations/) (reference — agent threats) | scoped delegated identity ([RFC 8693](https://datatracker.ietf.org/doc/html/rfc8693) (reference)) + OPA tool authz + `interrupt()` gate + [SPIFFE](https://spiffe.io/) (reference) mTLS | [NIST AI RMF](https://www.nist.gov/itl/ai-risk-management-framework) (reference) + [MAESTRO](https://cloudsecurityalliance.org/blog/2025/02/06/agentic-ai-threat-modeling-framework-maestro) (reference — multi-agent) |
| **Exam anchor** | — | **SC-500** objective mapping (the `sc500` field per objective) | — |

## How it's carried
- **Notes** state the standards inline where a control or attack is taught.
- **Tracker** — objectives may carry a `standards:` field (defensive + offensive refs) alongside the existing `oss` (the tool) and `sc500` (the exam control). It renders as a column in `assessment/tracker.md`.
- **Convention:** cite the specific technique/control where it's meaningful (e.g. `ATT&CK T1611` ↔ `D3FEND D3-CI`, `OWASP LLM01` ↔ `ATLAS AML.T0051`), not just the framework name. Real, verified IDs only — never invented.

## The through-line
ATT&CK/ATLAS name *how an adversary acts*; D3FEND/CIS/guardrails name *what you build*; NIST CSF/AI RMF/CISA ZTMM name *how you govern and mature it*; SC-500 keeps the exam honest. A learner should be able to point at any lab and say which standard it implements and which technique proves it. **Domain 6 (Agentic Zero Trust, beyond-blueprint)** extends the spine to autonomous agents: the same PEP/PDP (800-207) posture and the same offense↔defense pairing (ATLAS agentic techniques ↔ scoped delegated identity + tool authz + action gating + SPIFFE mTLS), MAESTRO for the multi-agent threat model.

## How resources are cited
This curriculum's job is to say **exactly** what to read or watch — and no more. Every external link a note or lab points you at is a claim on your time; a link to a whole doc site wastes it. So resources follow one convention.

**Format** — a learning resource is cited as:

```
- [Resource — the specific thing](deep-url#anchor) `[necessity-tag]` (~NN min[, §range])
```

- **Deep-link + name the target.** The URL points at the exact page/section/anchor (`#anchor` when the page supports it), and the link text names the heading, chapter, or section to read — so you know what to open *without* clicking. A bare homepage or a `…/docs/` root is not a learning resource; it's a wild-goose chase.
- **State the range when only part is needed.** For a long page, book, or video, cite the bounded slice: sections (`§4–7`), chapters/pages (`ch. 2–3`), or video timestamps (`12:00–24:00`). Never cite a whole video — always the timestamp range to watch.
- **Scope the time estimate.** `(~NN min)` covers *only* the cited slice, not the whole resource. When you narrow a citation to a range, narrow the estimate to match.
- **Inline/prose links** follow the same rule: the sentence names what to read at the other end.

**`(reference)` — the escape hatch.** A link cited for *lookup or provenance* rather than required reading — a tool's home page, a framework's site, an API index, a spec's canonical URL — is marked `(reference)` (optionally `(reference — <scope>)`). This keeps homepage links honest: they're allowed *because* they're flagged as non-required. Use it only for genuine navigational/canonical references, never to dodge deep-linking a resource a learner must actually read. A `(reference)`-marked link is a navigational lookup, not a learning resource, so it carries no necessity tag.

**Necessity tag — which one you must actually open.** Specificity (above) says *what* to read; it says nothing about *whether you have to*. A learner facing four or five citations under one objective cannot tell the load-bearing one from the enrichment ones without opening every link, so every learning resource also carries a necessity tag, one of three values:

- `` `[required-for-lab]` `` — the note under-teaches something the primary lab needs; skip this link and the lab is not doable.
- `` `[required-for-quiz]` `` — the note under-teaches something in exam scope; skip this link and a quiz question has no answer in your notes.
- `` `[depth]` `` — enrichment. Skippable without being blocked on the lab or the exam.

**Placement.** The tag sits in backticks immediately after the link (and before the time estimate, when one is cited): `[Resource](url) `[required-for-lab]` (~NN min)`. On a citation with no time estimate — a "Primary sources" list, an inline prose link — the tag goes at the end of the line it belongs to instead. One tag per line covers every link on that line, the same way one `(reference)` marker exempts the whole line.

**Defaults.** Most links resolve to `[depth]` — that's confirmation the notes are self-contained, not an oversight. Reach for `required-for-lab`/`required-for-quiz` only when the note genuinely offloads teaching to that specific link; when in doubt, it's depth.

**Enforcement.** `npm run lint:content` (study-hub) and the repo-side `scripts/lint-links.mjs` (oss-500 CI) fail on a host-only or documentation-root link in `domains/**` or `labs/**` that isn't marked `(reference)`, and separately fail on a learning link that carries no necessity tag and no `(reference)` marker. Both standards are checked, not just intended.
