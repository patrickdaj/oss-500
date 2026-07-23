# Phase 2 — Secrets, data, and networking

Domain 2 is the **heaviest SC-500 domain (25–30%)**, so this phase gets **more days than any other** — mirroring the exam weighting. You'll stand up a real secrets manager, hand short-lived credentials to workloads, automate certificate lifecycle, segment east-west traffic to default-deny, terminate TLS and screen requests with a WAF, and finally encrypt data at rest and hunt for leaked secrets.

**Milestone (end of phase):** every Domain 2 objective green in the tracker, and **Checkpoint 2 ≥ 80%**.

**Resource plan.** Per the [overview footprint table](overview.md#local-resource-readiness), this phase brings up Vault, cert-manager, ingress + WAF, and a service mesh — **~4–5 GB** if you follow the rule: **bring up only the current lab's component, tear it down when its lab is done.** The mesh and WAF are the heaviest here — tear them down right after their labs. Every lab block ends with the component's `./down.sh`. **Day 7 (Cilium fabric) is the one exception to cluster reuse:** it deletes the shared `oss500` cluster and rebuilds it with no default CNI / no kube-proxy, so it is deliberately placed **last**, after every kindnet-based lab — and you recreate the standard cluster before Phase 3 (the lab tells you how). ~16 GB host; run it after the day's other components are down.

Notes for this phase live in [`domains/2-secrets-data-networking/`](../domains/2-secrets-data-networking/); labs in [`labs/`](../labs/) (the `d2-*` guides); environments in [`lab-infra/`](../lab-infra/) (`secrets/`, `certs/`, `network/`, `encryption/`).

## Day 1 — Secrets manager fundamentals & access

- [ ] **[2h] Read: secrets manager concepts** — [secrets-management.md](../domains/2-secrets-data-networking/secrets-management.md) sections `vault-deploy` and `vault-access`. Anchor seal/unseal (Shamir vs auto-unseal), Raft vs external storage, and the Vault ≈ Azure Key Vault mapping. Path-based ACL policies vs Key Vault RBAC.
- [ ] **[1h] Bring up Vault** — `cd lab-infra/secrets && ./up.sh`. Watch it initialize; understand the init output (unseal shares + root token) and why it never enters git. Confirm `vault status` shows unsealed.
- [ ] **[2h] Lab (start): dynamic secrets — Parts A–B** — [d2-vault-dynamic-secrets](../labs/d2-vault-dynamic-secrets.md): Part A `vault-deploy` (status, seal model, Raft), Part B `vault-access` (enable an auth method, write a scoped HCL policy, log in, `vault token capabilities`).
- [ ] **[1h] Notes/quiz** — jot the policy HCL you wrote; skim the `vault-deploy`/`vault-access` quiz-2 questions. **Leave `lab-infra/secrets` up** — Day 2 continues on it (the one time a component survives overnight, per the overview rule: the next morning's first block continues it).

## Day 2 — Dynamic secrets, rotation, and audit

- [ ] **[2.5h] Lab (finish): dynamic secrets — Parts C–E** — [d2-vault-dynamic-secrets](../labs/d2-vault-dynamic-secrets.md): Part C `vault-dynamic` (database engine, `vault read database/creds/app`, watch the lease TTL expire, `vault lease revoke -prefix`), Part D `vault-rotation` (`rotate-root`, KV v2 versioning), Part E `vault-audit` (`vault audit enable file`, read a secret, inspect the HMAC'd log line).
- [ ] **[1.5h] Read + connect** — re-read [secrets-management.md](../domains/2-secrets-data-networking/secrets-management.md) `vault-dynamic`, `vault-rotation`, `vault-audit`; map each to the Azure control (managed credentials/rotation, Key Vault rotation, Key Vault diagnostics / Defender for Key Vault).
- [ ] **[1h] Verify the control** — prove a dynamic DB credential Postgres accepts **stops working** after lease expiry/revocation, and find your secret read in the audit log. That observable = the objective, not "Vault is installed."
- [ ] **[0.5h] Teardown** — `cd lab-infra/secrets && ./down.sh`? **No** — keep `secrets/` up for Day 3 (Vault Agent Injector + transit reuse it). Confirm no other stray components: `kubectl get all -A -l app.kubernetes.io/part-of=oss500`.

## Day 3 — Secrets to workloads + keys & transit

- [ ] **[2h] Lab: Vault → pods** — [d2-vault-k8s-injection](../labs/d2-vault-k8s-injection.md) (`vault-k8s`): Kubernetes auth role bound to a ServiceAccount, then deliver a secret via the **Agent Injector** annotations (`vault.hashicorp.com/agent-inject`) and via the **Secrets Store CSI** driver. Exec in and `cat /vault/secrets/…`.
- [ ] **[1.5h] Read: keys & certificates** — [keys-and-certificates.md](../domains/2-secrets-data-networking/keys-and-certificates.md) `key-transit` and `key-hsm`. Encryption-as-a-service; why the key never leaves Vault; HSM/PKCS#11 as the enterprise root of trust (≈ Managed HSM).
- [ ] **[1.5h] Lab: transit — Part A** — [d2-cert-manager](../labs/d2-cert-manager.md) Part A `key-transit`: enable the transit engine, encrypt/decrypt base64, rotate the key, observe the `vault:v1:` → `vault:v2:` ciphertext version prefix.
- [ ] **[0.5h] Teardown** — `cd lab-infra/secrets && ./down.sh`. Vault's job for this phase is done after transit; from here cert-manager stands alone. Confirm nothing lingers.

## Day 4 — Certificate lifecycle

- [ ] **[1h] Bring up cert-manager** — `cd lab-infra/certs && ./up.sh`; confirm the controller, webhook, and cainjector pods are ready.
- [ ] **[2.5h] Lab (finish): cert-manager — Parts B–D** — [d2-cert-manager](../labs/d2-cert-manager.md): Part B `cert-issuer` (a CA/selfSigned ClusterIssuer + a Certificate; inspect the issued `tls.crt` Secret), Part C `cert-lifecycle` (short `duration`/`renewBefore`, watch auto-renewal, `cmctl renew`, `cmctl status certificate`), Part D `key-hsm` **walkthrough** (PKCS#11 seal / SoftHSM — read at depth, mark the tracker row `walkthrough`).
- [ ] **[1h] Verify + map** — Certificate `Ready=True`, a **new `notAfter`** after renewal = the lifecycle control proven. Map to Key Vault certificates and certificate lifecycle management.
- [ ] **[0.5h] Teardown** — `cd lab-infra/certs && ./down.sh`; you'll reuse cert-manager conceptually for ingress TLS on Day 6 but bring it up fresh there. `kubectl get all -A -l app.kubernetes.io/part-of=oss500` clean.

## Day 5 — Network segmentation & service mesh

- [ ] **[2h] Read: network security** — [network-security.md](../domains/2-secrets-data-networking/network-security.md) `net-policy`, `net-mesh`, `net-firewall`. Default-deny east-west, podSelector/namespaceSelector, the DNS-egress footgun; mesh mTLS + identity-aware authorization; perimeter firewall vs NetworkPolicy layering.
- [ ] **[1h] Bring up the network stack** — `cd lab-infra/network && ./up.sh` (NetworkPolicy sets + mesh; kind's default **kindnet** enforces the basic NetworkPolicy these labs use — Calico is an *optional* manual `kubectl apply` add-on for advanced egress/`namespaceSelector` rules and is **not** installed by `up.sh`).
- [ ] **[2.5h] Lab: segmentation & mesh** — [d2-network-policy](../labs/d2-network-policy.md): Part A `net-policy` (prove two pods talk, apply **default-deny**, prove the curl **times out**, add a targeted allow, prove only that path works), Part B `net-mesh` (PeerAuthentication STRICT mTLS + AuthorizationPolicy allow/deny by principal), Part C `net-firewall` **walkthrough** (OPNsense/nftables perimeter — read at depth, mark `walkthrough`).
- [ ] **[0.5h] Teardown of the mesh** — the mesh is heavy: `cd lab-infra/network && ./down.sh` once verified, or scope down to just the ingress/WAF pieces you need Day 6. Confirm resources released before shutting down.

## Day 6 — Ingress TLS, WAF, and data protection

- [ ] **[2h] Lab: TLS ingress + WAF** — [d2-ingress-waf](../labs/d2-ingress-waf.md): Part A `net-ingress` (expose an app via ingress-nginx with a cert-manager-issued cert, curl `https://` and see the cert), Part B `waf-deploy` (enable ModSecurity; DetectionOnly → `SecRuleEngine On`), Part C `waf-rules` (OWASP CRS, paranoia level, anomaly threshold), Part D `waf-verify` (SQLi/XSS payload → **HTTP 403**, read the audit log rule id, tune a false positive with `SecRuleRemoveById`). Read [web-application-firewall.md](../domains/2-secrets-data-networking/web-application-firewall.md) alongside.
- [ ] **[0.5h] Teardown WAF/ingress** — `cd lab-infra/network && ./down.sh`. WAF is heavy; don't leave it running into the data-protection lab.
- [ ] **[2h] Lab: data at rest + secret scanning** — [d2-data-protection](../labs/d2-data-protection.md): read [data-protection.md](../domains/2-secrets-data-networking/data-protection.md); Part A `data-encrypt` (dump a Secret from etcd **plaintext**, apply the EncryptionConfiguration from `lab-infra/encryption`, re-encrypt existing Secrets, dump again to see `k8s:enc:` **ciphertext**), Part B `data-secretscan` (Trivy `fs --scanners secret` + image scan; Gitleaks `detect` on a planted credential).
- [ ] **[0.5h] Verify + teardown** — same etcd key plaintext-before / ciphertext-after; a Trivy and a Gitleaks finding. `cd lab-infra/encryption && ./down.sh`. End the day with a clean `kubectl get all -A -l app.kubernetes.io/part-of=oss500`.

## Day 7 — Cloud network fabric (Cilium)

The `d2-fabric` objective builds the classic L3 cloud-network fabric — VPC dataplane, NAT-gateway egress, cloud-firewall FQDN rules, and identity-attributed flow logs — on **Cilium**. It is placed last because it **rebuilds the cluster**: `fab-cni` needs a kind cluster with no default CNI and no kube-proxy, so this lab deletes the shared `oss500` cluster, stands up the Cilium one, and (at the end) recreates the standard kindnet cluster for Phase 3. Do it only after Days 1–6 are torn down.

- [ ] **[1.5h] Read: cloud network fabric** — [network-fabric.md](../domains/2-secrets-data-networking/network-fabric.md) (`fab-*`) with [04-linux-networking.md](../domains/0-fundamentals/04-linux-networking.md) as the substrate. Map each control to its cloud analog: VNet/VPC dataplane, NAT gateway (controlled egress), Azure Firewall application rules, NSG/VNet flow logs, VNet peering.
- [ ] **[1h] Lab Part A — Cilium as the CNI (`fab-cni`)** — [d2-network-fabric](../labs/d2-network-fabric.md): `kind delete cluster --name oss500`, create from `lab-infra/kind/cluster-cilium.yaml`, helm-install Cilium (resolve the API-server IP for `kubeProxyReplacement`), and get every node to `Ready`. **eBPF-fussy hosts:** on Docker Desktop, Parts B–D external UDP/DNS egress can be dropped by the LinuxKit VM — run kind inside a Linux VM (Lima) for those parts, the same fallback the Falco/Tetragon labs use.
- [ ] **[2.5h] Lab Parts B–D — egress, FQDN, flow logs** — Part B `fab-egress` (a `CiliumEgressGatewayPolicy` pins labelled pods to a fixed SNAT egress IP an external listener sees; an unlabelled pod does not), Part C `fab-fqdn` (a `CiliumNetworkPolicy` allowing DNS + only `docs.cilium.io:443` — allowed returns `200`, every other domain denied — plus the host firewall), Part D `fab-flowlogs` (Hubble shows the same traffic as one FORWARDED and one DROPPED flow, attributed to workload identity). Each observable is the objective.
- [ ] **[0.5h] Part E walkthrough + reset** — study `fab-peering` (Cluster Mesh needs two clusters — mark the tracker row `walkthrough`), then **recreate the standard cluster for Phase 3**: `lab-infra/network/cilium/down.sh`, `docker rm -f ext-listener`, `kind delete cluster --name oss500`, then `kind create cluster --name oss500 --config lab-infra/kind/cluster.yaml` and `lab-infra/shared/up.sh`. Confirm `kubectl get nodes` Ready on the standard kindnet cluster before Phase 3.

## Day 8 — Flex + Checkpoint

- [ ] **[2h] Weak-spot review** — revisit whichever objective's *observable* you couldn't reproduce cleanly (a lease that didn't revoke, a NetworkPolicy that didn't deny, a WAF that 200'd a SQLi). Re-run just that verification; the tracker shows which rows are still amber.
- [ ] **[1h] Walkthrough consolidation** — re-read the `key-hsm` and `net-firewall` walkthrough sections and be able to explain them cold; confirm those tracker rows are marked `walkthrough`, not skipped.
- [ ] **[1.5h] Checkpoint 2** — take the quiz (see below). Grade against the objective map so a wrong answer points at the exact note to reread.
- [ ] **[1h] Catch-up / rest** — absorb any Day 1–6 slippage here (never into Phase 3). Take your day off this week if you haven't. Final sanity: `docker ps` and `kubectl get all -A -l app.kubernetes.io/part-of=oss500` show nothing left running.

## Checkpoint

Take **Checkpoint 2** ([`assessment/data/quiz-2.yaml`](../assessment/data/quiz-2.yaml), `checkpoint-2`, domain `d2`) on this flex day. **Pass = ≥ 80%.**

- Each question maps to real `d2` objective ids, so a miss names the note/lab to redo.
- **If you score < 80%:** this flex day (and any spillover) goes to **remediating the missed objectives** — reread the note, re-run the lab's verification observable, then retake — **before** starting Phase 3. Per the [overview rules](overview.md#rules-that-keep-this-on-track), the tracker is the truth: an objective isn't done until its notes are read, its lab performed (or walkthrough studied), and its checkpoint questions passed.
- Domain 2 is the exam's largest slice — treat a marginal pass (80–84%) as a prompt to revisit the weakest subsection before the capstone.
