## 1. Add the read-ahead pointer to the Phase 0 plan

- [x] 1.1 In `plan/phase0-fundamentals.md`, Day 4 ("RBAC preview and flex"), add a short forward-reference line pointing to `domains/0-fundamentals/04-linux-networking.md` — name it as the Linux-networking substrate (netns/veth/CIDR/routing/NAT) and state the deep read is scheduled in Phase 2 alongside `network-fabric.md` / the `d2-network-fabric` lab. Write it as preview prose (mirroring the existing Day 4 RBAC-preview line), NOT as a `- [x] **[Nh]**` timed checkbox.
- [x] 1.2 Confirm the link path is repo-relative and resolves the same way the other Day-1/2/3 note links do (`../domains/0-fundamentals/04-linux-networking.md`).

## 2. Verify scope is preserved

- [x] 2.1 Confirm Day 1–3 blocks and their hour totals are unchanged, and the Phase 0 self-check is unchanged (no new study obligation added).
- [x] 2.2 Confirm `domains/0-fundamentals/04-linux-networking.md` and its existing Phase 2 links (`plan/phase2-secrets-data-networking.md`, `network-fabric.md`, `d2-network-fabric.md`) are untouched.
- [x] 2.3 Verify all six Phase 0 domain notes (`00`–`05`) are now reachable from `plan/phase0-fundamentals.md`.

## 3. Validate

- [x] 3.1 Run `openspec validate link-phase0-linux-networking-note` and resolve any issues.
- [x] 3.2 If the repo has a content link-checker (`lint:content` / equivalent), run it and confirm the new link resolves.
