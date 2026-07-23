# Tasks — fix-siem-agent-network

## 1. Fix the network name

- [x] 1.1 In `lab-infra/siem/agent-compose.yml`, set `networks.default.name: oss500-siem_default` (matching the `-p oss500-siem` project used by `up.sh`/`down.sh`/the lab).
- [x] 1.2 Confirm the agent service still references the manager by the resolvable name (`wazuh.manager`) on that network. (Unchanged: `WAZUH_MANAGER: wazuh.manager` on the shared network.)

## 2. Verify onboarding

- [x] 2.1 Confirm `labs/d4-siem-wazuh.md` Part B onboards the agent with the same `docker compose -p oss500-siem -f agent-compose.yml up -d` project. (Confirmed: lab lines 52/103/146 all use `-p oss500-siem`.)

## 3. Validation

- [x] 3.1 Mechanism verified with a throwaway busybox stack: `docker compose -p <proj>` creates `<proj>_default` (the `-p` flag overrides the file's `name:`), and an `external: true` consumer pointed at that exact name joins it — the previous `oss500_default` was never created. Full `lab-infra/siem` bring-up + enrollment still to be run on the host (heaviest stack; run alone).
- [ ] 3.2 (host) Confirm the agent appears **Active** in the Wazuh dashboard, generate SSH brute-force traffic, confirm parsed alert fields (`siem-collect`/`siem-detect`).
- [ ] 3.3 (host) `cd lab-infra/siem && ./down.sh -v`; confirm the stack and its network are gone.
- [x] 3.4 Run `npx openspec validate fix-siem-agent-network --strict`. (Passes.)
