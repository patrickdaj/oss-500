## 1. Coordinate & prerequisites (apply-time)

- [ ] 1.1 Re-read the then-current `assessment/data/tracker.yaml`, `domains/2-secrets-data-networking/network-security.md`, `labs/README.md`, and `assessment/data/quiz-2.yaml` (the `ztna-models-and-purple-team` change may have edited them); confirm no id/dir collisions with `fab-*` / `lab-infra/network/cilium/`
- [ ] 1.2 Pick and pin a Cilium version certified for egress gateway + FQDN policy + Hubble on kind; document the Lima/Linux-VM fallback for eBPF-fussy hosts

## 2. Lab infrastructure — Cilium mode

- [ ] 2.1 Add a documented "Cilium mode" cluster bring-up to `lab-infra/kind/` + `lab-infra/shared/` (kind with default CNI disabled; Cilium via Helm with egressGateway, hostFirewall, and Hubble enabled)
- [ ] 2.2 Create `lab-infra/network/cilium/`: `README.md` (scc-500-style, footprint + objectives), `up.sh`/`down.sh` (`set -euo pipefail`, `oss500` labels), Helm `values.yaml` with security settings commented against `fab-*` ids
- [ ] 2.3 Note the Terraform-automation path (helm + kubernetes providers) consistent with the ZTNA labs
- [ ] 2.4 Verify Cilium mode brings up and tears down cleanly on the reference host

## 3. Curriculum notes

- [ ] 3.1 Write the Linux-networking substrate fundamentals note (`domains/0-fundamentals/…`): netns, bridges, CIDR/subnetting, `ip route`, NAT/`MASQUERADE`, tied to the VPC/subnet/route-table cloud model
- [ ] 3.2 Write `d2-fabric` notes (in `network-security.md` as new sections, or a new `network-fabric.md` referenced by tracker `notes`): `fab-cni`, `fab-egress`, `fab-fqdn`, `fab-flowlogs`, `fab-peering` — each with the OSS↔Azure mapping, real Cilium config, gotchas, timed resources, `standards` refs
- [ ] 3.3 Cross-link the retained `net-firewall` appliance walkthrough to the hands-on `fab-fqdn` control

## 4. Tracker & data

- [ ] 4.1 Add the `d2-fabric` subsection to `tracker.yaml` (after `d2-network`) with the 5 objectives, `oss`/`sc500`/`standards`/`lab` fields (`fab-peering` = walkthrough)
- [ ] 4.2 Append checkpoint questions to `quiz-2.yaml` covering every `fab-*` id (zero-based answers, resolving `objectiveIds`)
- [ ] 4.3 Run `npm run gen:md`; confirm `tracker.md` + `checkpoint-2.md` regenerate

## 5. Lab

- [ ] 5.1 Write `labs/d2-network-fabric.md` (standard format): parts per objective with observable verification — fixed egress IP seen at an external listener (`fab-egress`), FQDN allowlist blocks a non-approved domain (`fab-fqdn`), Hubble shows allowed vs denied flow (`fab-flowlogs`), Cluster Mesh peering steps (`fab-peering`, walkthrough)
- [ ] 5.2 Add the catalog row to `labs/README.md` mapping `d2-fabric` → the lab → type → Cilium components

## 6. Verification

- [ ] 6.1 Coverage check: every `fab-*` id appears as a note heading, in the lab, and in a quiz question; `net-firewall` still present as walkthrough
- [ ] 6.2 study-hub: bump the `content/oss-500` submodule, run `npm run lint:content` + `npm test` green; confirm the fabric note/lab and `lab-infra/network/cilium/README.md` render
- [ ] 6.3 No dead links; secrets scan clean (no committed kubeconfigs/keys from Cilium)
