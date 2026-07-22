# agent-workload / agent-mtls — SPIRE registration for the agent SVID(s)

**SPIRE is not deployed by any lab-infra component** — `d1-workload-identity` covers SPIFFE/SPIRE as a walkthrough. The steps below are **directions**: stand up a SPIRE server/agent yourself (e.g. the SPIRE Helm chart, into `oss500-identity`) before running them. Once it is running, the agent process
gets a **SPIFFE SVID** as its *workload* identity — separate from the user-delegated token
(`../keycloak/token-exchange.md`). For multi-agent, peers authenticate each other with **SPIFFE mTLS**.

## Register the agent workload (directions)

```bash
# On the SPIRE server (one you deployed — not shipped by lab-infra/identity):
kubectl -n oss500-identity exec deploy/spire-server -- \
  /opt/spire/bin/spire-server entry create \
    -spiffeID  spiffe://oss500.local/ns/oss500-apps/sa/agent-a \
    -parentID  spiffe://oss500.local/ns/oss500-apps/sa/spire-agent \
    -selector  k8s:ns:oss500-apps \
    -selector  k8s:sa:agent-a
```

`agent-a` (and, for `d6-multi-agent`, `agent-b`) each get a distinct SVID. The agent fetches its SVID
from the Workload API and uses it as the client cert when calling the MCP server and peer agents.

## Prove it

- **`agent-workload` (labs/d6-identity.md):** the agent presents its SVID to the MCP server; a process
  without a valid SVID is rejected — workload identity ≠ delegated authority.
- **`agent-mtls` (labs/d6-multi-agent.md):** agent-b requires agent-a's SVID over mTLS; an
  unauthenticated peer is refused. A poisoned agent-a cannot make agent-b exceed agent-b's own authz.

## Walkthrough

**Multi-region / federated SPIRE trust domains** (cross-cluster agent trust) is a **walkthrough** —
it needs federated bundles across trust domains that aren't practical to run fully on one laptop host.
