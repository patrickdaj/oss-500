# Tasks — flag-lab-validation-status

## 1. Course-level disclosure

- [x] 1.1 Add a short **"Validation status"** section near the top of `labs/README.md`: the curriculum is newly authored; `lab-infra` is real/reviewable and much is verified as far as a laptop allows; some observables await an author host-run; per-lab "Validation status" lines mark which; a stuck step is a finding to report (Domain-5 honesty ethic).

## 2. Per-lab host-pending markers

Add a `> **Validation status — host-pending.** …` blockquote under the `## Verification` section (naming the exact deferred step and what *was* verified) to:

- [x] 2.1 `labs/d2-vault-dynamic-secrets.md` — Part A **Raft init/unseal bring-up on kind** is pending; the dynamic-secrets flow (creds → `lease revoke` → `rotate-root`) is verified.
- [x] 2.2 `labs/d3-ai-security.md` — the **NeMo Guardrails rails + model round-trip** on kind is pending; the gateway authn (401) / rate-limit (429) / OPA decisions are verified.
- [x] 2.3 `labs/d5-ai-redteam.md` — depends on the D3 gateway; **garak-against-the-guardrail** on kind is pending for the same reason.
- [x] 2.4 `labs/d6-identity.md` and `labs/d6-multi-agent.md` — the **SPIRE chart bring-up + SVID issuance** on kind is pending; the manifests/wiring and the removal of the false "reused from Domain 1" claims are done.
- [x] 2.5 `labs/d1-ztna-boundary.md` — full **`boundary connect` cert injection** against a CA-trusting target is pending; the Vault SSH-CA setup and `terraform validate` are verified.
- [x] 2.6 `labs/d4-siem-wazuh.md` — full **Wazuh agent enrollment** is pending; the agent-network fix mechanism is verified.

## 3. Validation

- [x] 3.1 `grep -rn "Validation status" labs/` shows the course-level disclosure + the six per-lab markers; each names a concrete step.
- [x] 3.2 Run `npm run lint:links` and `npx openspec validate flag-lab-validation-status --strict`.
- [ ] 3.3 As each host-pending observable is later validated on-host, flip its marker to the positive form (ongoing, outside this change).
