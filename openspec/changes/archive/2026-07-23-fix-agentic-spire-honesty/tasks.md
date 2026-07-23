# Tasks — fix-agentic-spire-honesty

## 1. Decide the resolution (design)

- [x] 1.1 **Chosen: (A) ship a real minimal SPIRE** under `lab-infra/agentic/spire/`.

## 2. Remove the false "already running" claims

- [x] 2.1 `labs/d6-identity.md`: replaced "reused from `lab-infra/identity`" with "the SPIRE server that `lab-infra/agentic` deploys"; changed the `exec deploy/spire-server` step to `exec statefulset/spire-server -c spire-server` (the chart's StatefulSet).
- [x] 2.2 Same fixes in `labs/d6-multi-agent.md`, `domains/6-agentic-zero-trust/d6-identity.md`, and both passages of `plan/phase6-agentic-zero-trust.md` (the plan now says SPIRE is deployed here, not directions-only). Grep confirms no residual "reused from Domain 1 / not deployed / stand up yourself" claims and no `deploy/spire-server`.

## 3a. Option A — ship SPIRE

- [x] 3a.1 Added `lab-infra/agentic/spire/values.yaml` (spiffe/spire Helm values: trust domain `oss500.local`, controller-manager on) and `clusterspiffeids.yaml` (ClusterSPIFFEID CRs auto-registering `agent-a`/`agent-b` SVIDs by pod label + namespace).
- [x] 3a.2 Wired `lab-infra/agentic/up.sh` to `helm install spire-crds` + `spire` into `oss500-identity` and apply the ClusterSPIFFEIDs; `down.sh` uninstalls them; rewrote `registration.md` into real steps (SPIRE deployed by up.sh; auto-register + manual `entry create` + verify). README/file-tree updated.

## 3b. Option B — mark as walkthrough

- [x] 3b.1 N/A — option A chosen.
- [x] 3b.2 N/A — only true federated-SPIRE remains a walkthrough (unchanged).

## 4. Validation

- [x] 4.1 Static: `values.yaml`/`clusterspiffeids.yaml` YAML-parse clean; `up.sh`/`down.sh` `bash -n` clean; no lab step references a `spire-server` the component doesn't deploy.
- [ ] 4.2 (host) `cd lab-infra/agentic && ./up.sh` on kind: confirm the SPIRE chart comes up, `spire-server entry show` lists the agent-a/agent-b SVIDs, and `labs/d6-identity.md` step 1 runs clean. (The `spiffe/spire` hardened chart may need a chart-version pin on first real run — confirm on the host.)
- [x] 4.3 `npm run lint:links` OK; `npx openspec validate fix-agentic-spire-honesty --strict` passes.
