## MODIFIED Requirements

### Requirement: Phased learning path calibrated to SC-500 domain weights
The plan SHALL define a phased schedule under `plan/`: a Phase 0 fundamentals ramp (Linux, containers, Kubernetes basics, IaC primer) followed by domain phases sequenced in SC-500 outline order, with total time per domain roughly proportional to its SC-500 exam weight, and a final review phase. Each phase SHALL name its focus, its milestone, and a day-by-day breakdown.

#### Scenario: Phase plan exists per phase
- **WHEN** a reader opens `plan/` for any phase
- **THEN** they find a plan naming its focus (fundamentals ramp, an SC-500 domain with its weight percentage, or review), the phase milestone, and a day-by-day breakdown

#### Scenario: Fundamentals ramp precedes security content
- **WHEN** a reader opens the Phase-0 plan
- **THEN** it covers Linux/CLI, Docker/OCI images, Kubernetes primitives (pods, services, deployments, RBAC), Helm, and a k3s + IaC primer sufficient to stand up the lab cluster, and states it is a ramp — not the security curriculum

#### Scenario: IaC primer links the git and Terraform foundation note
- **WHEN** a reader reaches the Phase-0 day that introduces the IaC loop
- **THEN** that day links `domains/0-fundamentals/05-git-iac-foundation.md` (the git model and Terraform write→plan→apply foundation) as reading to precede the applied kind/Helm work, and the phase self-check exercises the git working-tree/index/repo model and Terraform state/locking

#### Scenario: Phase-0 plan points to the Linux-networking substrate note as a Phase-2 read-ahead
- **WHEN** a reader works through the Phase-0 plan
- **THEN** the plan links `domains/0-fundamentals/04-linux-networking.md` at least once as the Linux-networking substrate (netns/veth/CIDR/routing/NAT) and states that its deep read is scheduled in Phase 2 alongside `network-fabric.md` / the `d2-network-fabric` lab, so every Phase-0 domain note is reachable from the Phase-0 plan without adding a full timed study block or relocating the note

#### Scenario: Heaviest domain gets the most time
- **WHEN** comparing planned hours across domains
- **THEN** the secrets/data/networking domain (SC-500 weight 25–30%) receives more planned hours than any other domain
