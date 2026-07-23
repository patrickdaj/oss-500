# Put the Wazuh agent on the same docker network as the manager

## Why

Phase 4 Day 3 onboards a Wazuh agent to the SIEM, and four of the lab's five stages (`siem-collect`, `siem-detect`, `siem-hunt`, `siem-response`) depend on that agent enrolling. It never does, because of a docker-compose network-name mismatch.

Everything in `lab-infra/siem/` runs under `docker compose -p oss500-siem` (see `up.sh`, `down.sh`, and `labs/d4-siem-wazuh.md` Parts A–B), so the stack's network is **`oss500-siem_default`**. But `lab-infra/siem/agent-compose.yml` attaches the agent to:

```yaml
networks:
  default:
    name: oss500_default
    external: true
```

The `-p oss500-siem` project flag overrides the compose file's own `name:`, so `oss500_default` is a *different*, non-existent network. Declared `external: true`, Compose won't create it — so `docker compose -p oss500-siem -f agent-compose.yml up -d` errors with "network oss500_default declared as external, but could not be found" (or, if forced up, the agent can't resolve `wazuh.manager`). Either way the agent never registers, and the learner is stuck on the SIEM's core loop.

## What Changes

- Change `lab-infra/siem/agent-compose.yml` `networks.default.name` to **`oss500-siem_default`** (matching the `-p oss500-siem` project used everywhere else), so the agent lands on the manager's network and can resolve `wazuh.manager`.
- Confirm the onboarding step in `labs/d4-siem-wazuh.md` Part B brings the agent up with the same `-p oss500-siem` project and that enrollment shows in the manager.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `lab-infrastructure` — adds a requirement that multi-file Docker Compose stacks use a consistent project/network name so companion services (e.g. an agent) actually join the primary stack's network.

## Impact

- Affected specs: `lab-infrastructure` (one ADDED requirement).
- Affected content (at implementation time): `lab-infra/siem/agent-compose.yml` (one line), and a verification pass on `labs/d4-siem-wazuh.md` Part B.
- Unblocks `siem-collect`, `siem-detect`, `siem-hunt`, `siem-response`.
