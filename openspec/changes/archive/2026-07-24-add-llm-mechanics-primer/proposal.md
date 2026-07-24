# Add an LLM-mechanics primer beneath the D3 AI-security threat model

## Why

`domains/3-compute-ai/ai-security.md` builds the LLM threat model from zero and does it well — but it assumes the *mechanics* underneath: token and tokenization, context window, the system-vs-user prompt split, embeddings, vector stores, and the RAG retrieve→augment→generate loop are all used as known vocabulary in the intro. This is precisely the AI-newcomer half of the persona. The course gives him a Linux/containers on-ramp for the compute half of the domain, but there is **no AI on-ramp** — so the first place these terms could be learned is the note that already reasons over them.

The gap is *mechanics*, not security teaching: the threat model is strong and should not be churned. What's missing is the substrate beneath it.

## What Changes

- Add an **LLM-mechanics primer** — as a new `0-fundamentals` note or a D3 preamble placed ahead of `ai-security.md` — covering token & tokenization, the context window, system vs user prompts, embeddings, vector stores, and the RAG loop (retrieve → augment → generate).
- Cross-link the primer from `ai-security.md` and from the secure-RAG objective that first depends on the RAG loop, so the mechanics are single-sourced and the existing threat-model content is left intact.
- Flag it concept-new, consistent with the AI-security notes already flagged concept-new.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `oss-curriculum` — adds a requirement that the LLM mechanics the AI-security notes assume are taught in an AI on-ramp before `ai-security.md`, without displacing its threat-model content.

## Impact

- Affected specs: `oss-curriculum` (one ADDED requirement).
- Affected content (at implementation time): a new `0-fundamentals`/D3-preamble LLM-mechanics note, cross-linked from `ai-security.md` and the secure-RAG objective.
- Closes the missing AI on-ramp so the D3 threat-model teaching stands on defined vocabulary rather than assumed knowledge.
