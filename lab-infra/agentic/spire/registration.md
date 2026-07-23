# agent-workload / agent-mtls — the agent SVID(s) on SPIRE

**SPIRE is deployed by `lab-infra/agentic/up.sh`** (the `spiffe/spire` Helm chart into
`oss500-identity`: server + agent DaemonSet + SPIFFE CSI driver + controller-manager). Domain 1
covered SPIFFE/SPIRE only as a *walkthrough* — nothing ran there — so this is where SPIRE actually
runs. The agent process gets a **SPIFFE SVID** as its *workload* identity, separate from the
user-delegated token (`../keycloak/token-exchange.md`); for multi-agent, peers authenticate each
other with **SPIFFE mTLS**.

## How the SVIDs are registered

`up.sh` applies [`clusterspiffeids.yaml`](clusterspiffeids.yaml): the controller-manager watches those
`ClusterSPIFFEID` CRs and issues an SVID to every matching pod — so `agent-a` and `agent-b` each get a
distinct identity `spiffe://oss500.local/ns/oss500-apps/sa/<serviceAccount>` with **no manual step**,
as soon as those pods run with the SPIFFE CSI socket mounted.

The equivalent **manual** registration (the concept the exam frames) is a `spire-server entry create`:

```bash
kubectl -n oss500-identity exec statefulset/spire-server -c spire-server -- \
  /opt/spire/bin/spire-server entry create \
    -spiffeID  spiffe://oss500.local/ns/oss500-apps/sa/agent-a \
    -parentID  spiffe://oss500.local/ns/oss500-apps/sa/spire-agent \
    -selector  k8s:ns:oss500-apps \
    -selector  k8s:sa:agent-a
```

## Verify

```bash
# SPIRE is up:
kubectl -n oss500-identity get pods -l app.kubernetes.io/name=server
# The registration entries exist (one per ClusterSPIFFEID / manual create):
kubectl -n oss500-identity exec statefulset/spire-server -c spire-server -- \
  /opt/spire/bin/spire-server entry show
```

- **`agent-workload` (labs/d6-identity.md):** the agent presents its SVID to the MCP server; a process
  without a valid SVID is rejected — workload identity ≠ delegated authority.
- **`agent-mtls` (labs/d6-multi-agent.md):** agent-b requires agent-a's SVID over mTLS; an
  unauthenticated peer is refused. A poisoned agent-a cannot make agent-b exceed agent-b's own authz.

## Walkthrough

**Multi-region / federated SPIRE trust domains** (cross-cluster agent trust) stays a **walkthrough** —
it needs federated bundles across trust domains that aren't practical to run fully on one laptop host.
