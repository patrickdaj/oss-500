## 1. Write the note

- [x] 1.1 Write `domains/0-fundamentals/05-git-iac-foundation.md` — a git foundation (version-control model, commits/branches/remotes, repo-as-source-of-truth / GitOps) and a Terraform foundation (providers, state + locking, modules, write→plan→apply, remote state), each closing with "why it matters for this course". Match the Domain 0 note voice; links per the `resource-citation` standard.
- [x] 1.2 Add a one-line cross-link in `domains/0-fundamentals/03-kind-helm-iac.md` pointing to `05-git-iac-foundation.md` as its Terraform underpinning; point the new note forward to `gov-iac`.

## 2. Verify & finalize

- [x] 2.1 `npm run lint:links` passes over the new note (deep links or `(reference)`; no host-only/doc-root).
- [x] 2.2 `openspec validate add-git-iac-foundation` passes; confirm no `tracker.yaml`/objective change.
- [x] 2.3 study-hub: bump the `content/oss-500` submodule, run `npm run lint:content` + `npm test` green, confirm the note renders as Phase 0 reading.
