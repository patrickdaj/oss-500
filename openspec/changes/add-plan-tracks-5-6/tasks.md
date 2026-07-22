## 1. Phase 5 — offensive validation

- [x] 1.1 Create `plan/phase5-offensive-validation.md` with the standard anatomy: `# Phase 5 — Offensive validation`, an intro paragraph framing it as **beyond-blueprint** (no exam weight), and a "where things live" line pointing at `domains/5-offensive-validation/`, `labs/`, and `lab-infra/`.
- [x] 1.2 Day 1 — Purple-team method (`pt-method`): link `domains/5-offensive-validation/purple-team.md`; blocks build the "name the technique → fire it → confirm detection" loop that frames every later lab.
- [x] 1.3 Day 2 — AI red-teaming (`av-ai-garak`, `av-ai-pyrit`): link `domains/5-offensive-validation/ai-redteam.md` and `labs/d5-ai-redteam.md`; observable = garak/pyrit surfaces a jailbreak the guardrail missed and it is closed.
- [x] 1.4 Day 3 — Infra attack simulation (`av-atomic`, `av-caldera-stratus`): link `domains/5-offensive-validation/infra-attack-simulation.md` and `labs/d5-infra-attack-simulation.md`; fire ATT&CK techniques and confirm the Phase 4 detection stack alerts.
- [x] 1.5 Day 4 — ZTNA authorization testing (`av-ztna-authz`): link `domains/5-offensive-validation/ztna-authz.md` and `labs/d5-ztna-authz.md`; prove least privilege holds / denies as expected.
- [x] 1.6 Final day — synthesis/flex + Checkpoint 5: direct taking [checkpoint-5](../assessment/checkpoint-5.md) in test mode; a below-bar score routes remaining time to remediation (missed questions → tracker objective). Also confirm each lab's proof-of-work observable and filter the tracker for `d5` confidence.

## 2. Phase 6 — agentic zero trust

- [x] 2.1 Create `plan/phase6-agentic-zero-trust.md` with the standard anatomy: `# Phase 6 — Agentic zero trust`, beyond-blueprint intro, and "where things live" line pointing at `domains/6-agentic-zero-trust/`, `labs/`, `lab-infra/`.
- [x] 2.2 Day 1 — Agent delegated identity (`agent-workload`, `agent-deleg`): link `domains/6-agentic-zero-trust/d6-identity.md` and `labs/d6-identity.md`; workload SVID vs. scoped on-behalf-of token.
- [x] 2.3 Day 2 — Tool / MCP trust boundaries (`mcp-authz`, `mcp-authn`): link `domains/6-agentic-zero-trust/d6-tools-mcp.md` and `labs/d6-tools-mcp.md`; authorize every call, authenticate every caller.
- [x] 2.4 Day 3 — Autonomous-action gating (`action-gate`): link `domains/6-agentic-zero-trust/d6-action-gating.md` and `labs/d6-action-gating.md`; observable = an over-scoped action is paused at the gate and denied.
- [x] 2.5 Day 4 — Multi-agent trust (`agent-mtls`, `agent-cascade`): link `domains/6-agentic-zero-trust/d6-multi-agent.md` and `labs/d6-multi-agent.md`; SPIFFE mTLS, no privilege laundering across the chain.
- [x] 2.6 Day 5 — Red-team the agent (`av-agent-actions`): link `domains/6-agentic-zero-trust/d6-validate.md` and `labs/d6-validate.md`; attack the action/identity surface and confirm the controls hold.
- [x] 2.7 Final day — synthesis + Checkpoint 6: direct taking [checkpoint-6](../assessment/checkpoint-6.md) in test mode; a below-bar score routes remaining time to remediation. Also confirm each lab's proof-of-work observable and filter the tracker for `d6` confidence.

## 3. Overview sync

- [x] 3.1 Add phase-map rows for `phase5-offensive-validation.md` and `phase6-agentic-zero-trust.md` between phase 4 and Review, with an em-dash exam-weight cell and a checkpoint-gated milestone (mirroring the phase 1–4 rows).
- [x] 3.2 Add resource-readiness rows for phases 5/6 (state that they reuse the Phase 3/4 detection + Phase 1 identity stacks plus lightweight attack tooling; mark host-constrained items walkthrough).
- [x] 3.3 Fix the intro/narrative so it no longer claims the plan has only "six phases"; keep the Review row last in both tables.

## 4. Verify

- [x] 4.1 Run `npm run lint:links` — all links in the new/edited plan files resolve.
- [x] 4.2 Confirm every tracker domain `dN` now has a `plan/phaseN-*.md` (0–6 + review present).
- [ ] 4.3 Commit in oss-500. Then in study-hub advance the `content/oss-500` submodule to the new commit, `git add content/oss-500`, commit, run the app, and confirm the Plan view lists phases 5 and 6 with checkable blocks.
