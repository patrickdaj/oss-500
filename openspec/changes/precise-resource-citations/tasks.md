## 1. Define the citation standard

- [x] 1.1 Write the `resource-citation` standard into `domains/standards-map.md` (a short "How resources are cited" section): the format `- [Resource — the specific thing](deep-url#anchor) (~NN min[, §range])`; the rule that a learning resource must deep-link + name the section/chapter/timestamp to read; ranges for partially-needed resources; and the `(reference)` marker for canonical/navigational links. This section is the source of truth the audit and lint enforce.
- [x] 1.2 Convert `standards-map.md`'s own framework/tool homepages (ATT&CK, D3FEND, CIS, NIST CSF/AI RMF, OWASP, CISA ZTMM, SC-500) to explicit `(reference)` links per the standard (they are canonical references, not required reading).

## 2. Audit content — make every learning resource specific

For each file: deep-link every learning resource to the exact page/anchor, name the section/heading (and chapter/page or timestamp range when only part is needed), scope `(~NN min)` to the cited slice, and mark true lookup links `(reference)`. Open each link and confirm the named section actually exists before moving on.

- [x] 2.1 `domains/0-fundamentals/` (5 files: `00-linux-cli`, `01-containers`, `02-kubernetes`, `03-kind-helm-iac`, `04-linux-networking`) — the "Primary sources" blocks are the densest offenders (host-only / doc-root links); fix all.
- [x] 2.2 `domains/1-identity-governance/` (6 files, incl. `identity-provider.md` @30 links, `governance.md` @20, `kubernetes-rbac.md`/`workload-identity.md` @15, `privileged-access.md` @14, `ztna-access-models.md`).
- [x] 2.3 `domains/2-secrets-data-networking/` (6 files, incl. `secrets-management.md` @28, `keys-and-certificates.md`/`network-security.md` @20, `web-application-firewall.md`/`network-fabric.md` @14–15, `data-protection.md` @12).
- [x] 2.4 `domains/3-compute-ai/` (4 files: `ai-security.md` @28, `supply-chain.md` @18, `pod-security.md` @15, `runtime-security.md` @13).
- [x] 2.5 `domains/4-posture-monitoring/` (4 files: `observability.md` @24, `siem-incident-response.md` @23, `vulnerability-posture.md` @18, `network-detection.md` @12).
- [x] 2.6 `domains/5-offensive-validation/` (4 files: `infra-attack-simulation.md`, `ai-redteam.md`, `purple-team.md`, `ztna-authz.md`).
- [x] 2.7 `labs/**` — inline resource links in every lab (incl. `d1-kubernetes-rbac.md`, `d1-privileged-access.md`, `d2-network-fabric.md`, and any others); the "Notes read" pointers stay, but external resources follow the standard.
- [x] 2.8 Any videos encountered (currently none) — cite the timestamp/section range to watch, never the whole video.

## 3. Enforce it in lint

- [x] 3.1 Extend `study-hub/scripts/lint-content.mjs` with a link-specificity rule for `domains/**` + `labs/**`: fail on host-only URLs and a denylist of doc-root/landing patterns (e.g. `/docs/$`, `/docs/concepts/$`, `…/intro$`, homepage roots) **unless** the link line is marked `(reference)`; report file + link + reason.
- [x] 3.2 Mirror the rule as an `oss-500` repo-side script (e.g. `scripts/lint-links.mjs`, runnable in CI) so the content repo catches violations independently of study-hub; wire it where `gen:md`/CI can call it.
- [x] 3.3 Tune the denylist against the audited corpus so it flags the real offenders with no false negatives and no false positives that aren't legitimately `(reference)`.

## 4. Verify

- [x] 4.1 Coverage: no host-only or doc-root links remain in `domains/**`/`labs/**` except those marked `(reference)`; spot-check a sample of fixed links resolve to the named section.
- [x] 4.2 `npm run lint:content` passes in study-hub (with the new rule) and the repo-side link lint passes in `oss-500`.
- [x] 4.3 study-hub: bump the `content/oss-500` submodule, run `npm test` green, confirm notes/labs still render with the rewritten links.
- [x] 4.4 No dead links introduced; `(~NN min)` estimates updated wherever a citation was narrowed to a range.
