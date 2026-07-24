# Tasks — add-llm-mechanics-primer

## 1. Author the primer

- [ ] 1.1 Add an LLM-mechanics primer as a `0-fundamentals` note (or a D3 preamble) placed ahead of `domains/3-compute-ai/ai-security.md`.
- [ ] 1.2 Cover token & tokenization, the context window, system vs user prompts, embeddings, vector stores, and the RAG retrieve→augment→generate loop.
- [ ] 1.3 Flag the primer concept-new, consistent with the AI-security notes.

## 2. Cross-link and preserve

- [ ] 2.1 Cross-link the primer from `ai-security.md` and from the secure-RAG objective.
- [ ] 2.2 Confirm the existing `ai-security.md` threat-model content is left intact (mechanics added beneath it, not in place of it).

## 3. Validation

- [ ] 3.1 Run `openspec validate add-llm-mechanics-primer --type change --strict` and confirm it passes.
