## ADDED Requirements

### Requirement: Cloud-network-fabric constructs are taught on open-source tooling
The curriculum SHALL add a Domain-2 subsection `d2-fabric` whose objectives map each classic cloud virtual-network construct to a hands-on open-source equivalent and to its SC-500/Azure control, covering at minimum: the CNI/dataplane (VPC substrate), NAT-gateway egress control, cloud-firewall FQDN application rules, network flow logs, and virtual-network peering. Each objective SHALL carry a stable `id`, `oss`, `sc500`, and `lab` type in `tracker.yaml` and appear as a heading with content in the notes.

#### Scenario: Fabric subsection covers the core constructs
- **WHEN** a reader opens the `d2-fabric` notes
- **THEN** they find, each as a heading with content and a metadata line, coverage of: Cilium as CNI (`fab-cni`), egress gateway as NAT gateway (`fab-egress`), FQDN egress + host firewall as Azure Firewall (`fab-fqdn`), Hubble as flow logs (`fab-flowlogs`), and Cluster Mesh as VNet peering (`fab-peering`)

#### Scenario: Each construct names its cloud correspondence
- **WHEN** any `d2-fabric` objective is read
- **THEN** it names the OSS tool, the Azure/SC-500 construct it corresponds to (VPC/VNet, NAT gateway, Azure Firewall, NSG/VNet flow logs, VNet peering), and the transferable concept

### Requirement: NAT-gateway egress control is hands-on
The `fab-egress` objective SHALL be a hands-on lab in which a selected set of workloads egresses the cluster through a **fixed, known SNAT IP** (the Cilium Egress Gateway), verified by observing that source IP at an external listener — the open-source analog of a cloud NAT gateway / controlled egress.

#### Scenario: Fixed egress IP is observable
- **WHEN** a pod bound to the egress gateway makes an outbound connection to an external listener
- **THEN** the listener observes the configured gateway IP as the source, and a pod not bound to the gateway is observed with a different source — proving egress is controlled and attributable

### Requirement: Cloud-firewall FQDN rules replace the walkthrough with a hands-on control
The `fab-fqdn` objective SHALL enforce **DNS/FQDN-aware egress policy** (and host-level firewalling) as the hands-on analog of Azure Firewall application rules, verified by an allowed FQDN succeeding and a non-allowlisted FQDN being denied. The existing `net-firewall` objective SHALL be retained as the OPNsense/pfSense **appliance walkthrough** anchor, with `fab-fqdn` providing the hands-on enforcement it previously lacked.

#### Scenario: FQDN allowlist blocks a non-approved domain
- **WHEN** a workload is subject to an FQDN-allowlist egress policy
- **THEN** a request to an allowed FQDN succeeds and a request to a non-allowlisted FQDN is denied, observable in the tool's logs/flows

#### Scenario: Appliance walkthrough retained
- **WHEN** a reader reaches the perimeter-firewall material
- **THEN** the OPNsense/pfSense/nftables appliance model is still presented as a `walkthrough`, now cross-linked to the hands-on `fab-fqdn` control

### Requirement: Network flow logs are observable
The `fab-flowlogs` objective SHALL make cluster network flows observable via **Hubble** (the NSG/VNet flow-logs analog), verified by identifying a specific allowed and a specific denied flow after a policy is applied.

#### Scenario: Flows are visible and attributable
- **WHEN** a NetworkPolicy or fabric egress rule is applied and traffic is generated
- **THEN** the allowed and denied flows are visible in Hubble with source/destination identity, mirroring how NSG/VNet flow logs attribute traffic

### Requirement: Virtual-network peering is documented as a walkthrough
The `fab-peering` objective SHALL document **Cilium Cluster Mesh** as the VNet-peering / hub-spoke analog and be marked `walkthrough` (it requires two clusters, beyond the single-host reference), with the exact configuration steps enumerated as if performed.

#### Scenario: Peering marked walkthrough with full steps
- **WHEN** a reader opens the `fab-peering` material
- **THEN** it is marked `walkthrough`, explains cross-cluster service discovery and cross-cluster policy as the peering analog, and lists the Cluster Mesh setup steps

### Requirement: The raw substrate is grounded in Linux networking fundamentals
A fundamentals note SHALL ground the VPC/subnet/route-table mental model in Linux primitives — network namespaces, bridges, CIDR/subnetting, `ip route`, and NAT (`MASQUERADE`) — so learners understand what Cilium abstracts before using it.

#### Scenario: Substrate note exists and is referenced
- **WHEN** a reader begins the fabric material
- **THEN** a fundamentals note explains netns/bridges/CIDR/routing/NAT and is referenced from the `d2-fabric` notes and the fabric lab

### Requirement: Fabric lab environment is reproducible and Terraform-automatable
`lab-infra/` SHALL provide a `network/cilium/` component (Helm values + `up.sh`/`down.sh` + `README.md`) that installs Cilium as the CNI with egress gateway, host firewall, and Hubble enabled, integrated with the kind/shared cluster bring-up, and documented as Terraform-automatable consistent with the ZTNA labs. Security-relevant settings SHALL be commented against the fabric objective they implement.

#### Scenario: Cilium mode brings up the fabric controls
- **WHEN** the cluster is brought up in Cilium mode and `lab-infra/network/cilium/up.sh` is run
- **THEN** NetworkPolicy, the egress gateway, host/FQDN firewalling, and Hubble are available, and teardown removes them cleanly

### Requirement: Fabric objectives are assessed
Each `d2-fabric` objective SHALL be covered by at least one checkpoint question in the Domain-2 quiz bank, with `objectiveIds` resolving to the new tracker ids.

#### Scenario: Every fabric objective has a quiz question
- **WHEN** the Domain-2 quiz bank is validated
- **THEN** every `d2-fabric` objective id appears in at least one question's `objectiveIds`
