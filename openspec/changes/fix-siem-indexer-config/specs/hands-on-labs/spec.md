## ADDED Requirements

### Requirement: The d4-siem-wazuh alert observable is reachable and host-validated
The `d4-siem-wazuh` lab's concrete verification — a crafted SSH brute-force producing a **parsed alert document** — SHALL be reachable on the running stack, not blocked by SIEM infrastructure that cannot start. Once the indexer boots healthy (see the `lab-infrastructure` delta), the end-to-end path SHALL be exercised on a host: onboarding the agent, injecting at least six crafted sshd "Failed password" lines into the agent's monitored `auth.log`, and confirming the built-in sshd rule (5710) escalates to the custom correlation rule (100100) and lands an alert in `wazuh-alerts-*` whose parsed fields (e.g. `data.srcip`, `rule.id`, `rule.mitre.id`) are queryable via the indexer `_search` API. After a successful run the lab's `Validation status` note for this observable SHALL be updated from `host-pending` to `host-validated`.

#### Scenario: Crafted brute-force yields a parsed alert document
- **WHEN** the agent is onboarded and six-plus crafted `Failed password ... from <ip>` lines are appended to its monitored `auth.log`
- **THEN** an alert document appears in `wazuh-alerts-*` with `rule.id` 100100 and parsed fields including `data.srcip` equal to the crafted source IP, retrievable via the indexer `_search` API

#### Scenario: Validation status reflects a real host run
- **WHEN** the alert observable has been exercised end-to-end on a host
- **THEN** the `d4-siem-wazuh` lab's `Validation status` note for that observable reads `host-validated`, naming what was run, rather than `host-pending`
