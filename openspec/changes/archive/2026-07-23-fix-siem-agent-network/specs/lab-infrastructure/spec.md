## ADDED Requirements

### Requirement: Companion Compose services join the primary stack's network
When a `lab-infra/` component is a multi-file Docker Compose stack whose companion services (such as an onboarded agent) must reach the primary services, all files SHALL be brought up under the same Compose project name and the companion SHALL attach to the network that project actually creates, so companion services can resolve and reach the primary services.

#### Scenario: The Wazuh agent lands on the manager's network
- **WHEN** a learner brings up the SIEM with `docker compose -p oss500-siem` and then onboards the agent from `agent-compose.yml` under the same project
- **THEN** the agent attaches to `oss500-siem_default` (the network that project creates), resolves `wazuh.manager`, and enrolls — rather than failing because the file names a different, non-existent external network

#### Scenario: Onboarding-dependent lab stages are reachable
- **WHEN** the agent has enrolled
- **THEN** the SIEM collect, detect, hunt, and response stages can be exercised against real agent-sourced events
