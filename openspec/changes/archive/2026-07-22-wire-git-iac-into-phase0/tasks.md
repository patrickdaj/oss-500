## 1. Wire the note into the Phase-0 plan

- [x] 1.1 In `plan/phase0-fundamentals.md` Day 3, add a leading reading block before "Stand up the lab cluster" that links `domains/0-fundamentals/05-git-iac-foundation.md` and frames it as the git + Terraform foundation to read before the applied kind/Helm work
- [x] 1.2 Add a Phase-0 self-check item covering the git working-tree/index/repo model and Terraform state + locking (mirroring the note's self-check)

## 2. Validate

- [x] 2.1 Run `npm run lint:links` and confirm the new link resolves (green)
- [x] 2.2 Run `openspec validate wire-git-iac-into-phase0 --strict` and confirm green
