## Context

Domain 0 fundamentals (`00-linux-cli` … `04-linux-networking`) are reading groundwork surfaced by study-hub's loader from their presence in `domains/0-fundamentals/` — they carry no tracker objectives. The course's later work assumes git and Terraform fluency (Terraform-automated ZTNA labs, the `gov-iac` IaC objective) but only `03-kind-helm-iac.md` touches Terraform, at intro depth, and nothing covers git. This change adds one fundamentals note to close that gap.

## Goals / Non-Goals

**Goals:**
- Give the learner a working git model (commits, branches, remotes, repo-as-source-of-truth / GitOps) and Terraform foundation (providers, state + locking, modules, write→plan→apply) sufficient to enter the IaC-automated labs prepared.
- Match the Domain 0 note voice and the `resource-citation` link standard.

**Non-Goals:**
- Not a lab (the user chose note-only); the hands-on IaC work stays in `gov-iac` / `03-kind-helm-iac`.
- No tracker/objective changes (fundamentals aren't tracked).
- Not a git/Terraform tutorial in full — foundation depth, pointing at official docs for the rest.

## Decisions

**D1 — One note, two halves.** `05-git-iac-foundation.md` = a git-foundation half and a Terraform-foundation half, each ending in "why it matters for this course" (git → GitOps/change-management and the lab repos; Terraform → the automated ZTNA labs and `gov-iac`). *Alternative:* two separate notes (`05-git`, `06-iac`) — rejected as heavier than the note-only scope warranted; one cohesive foundation note fits Phase 0.

**D2 — Position at the end of Phase 0, cross-linked.** Numbered `05-` (after networking), and `03-kind-helm-iac.md` gains a one-line pointer back to it as its Terraform underpinning. It points forward to `gov-iac`.

**D3 — Links per the standard.** Deep-link the specific git and Terraform doc sections (the git branching/model chapters, Terraform state/modules/workflow pages), or mark canonical homes `(reference)`, so `lint:links` passes.

## Risks / Trade-offs

- **Overlap with `03-kind-helm-iac`'s Terraform intro.** → This note is *foundation* (state, modules, workflow, git), that note is *applied* (kind/Helm/Terraform in the lab context); the cross-link makes the relationship explicit rather than duplicative.
- **study-hub phase ordering.** → A new note in `domains/0-fundamentals/` is picked up as Phase 0 reading by filename; it does not change tracker domains/objectives, so study-hub counts and tests are unaffected (confirm at finalize).

## Open Questions

- None material — scope is a single note.
