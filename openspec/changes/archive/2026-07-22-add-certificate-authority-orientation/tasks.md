## 1. Add the CA-selection orientation box

- [x] 1.1 In `domains/2-secrets-data-networking/keys-and-certificates.md`, add a short "which CA when" orientation box that maps each of the four certificate authorities to the use case it owns: **cert-manager** → edge/ingress + app TLS certificate lifecycle; **Vault PKI** (`vault` issuer / PKI engine) → app/internal PKI (and backing cert-manager); **Istio/Linkerd mesh CA** → east-west mesh mTLS SVIDs; **SPIRE trust-domain CA** → platform-agnostic SPIFFE SVID beyond a single mesh. Frame it as CA → use case, not a feature comparison; point each row at its home section/note. Match the note voice.

## 2. Cross-link from the other CA notes

- [x] 2.1 In `domains/2-secrets-data-networking/network-security.md` (`net-mesh`, where the Istio/Linkerd mesh CA is introduced), add a one-line cross-link to the orientation box in `keys-and-certificates.md`.
- [x] 2.2 In `domains/1-identity-governance/workload-identity.md` (`wi-spiffe`, where the SPIRE trust-domain CA is introduced), add a one-line cross-link to the orientation box in `keys-and-certificates.md`.

## 3. Verify & finalize

- [x] 3.1 `npm run lint:links` passes over the edited notes (relative cross-links resolve; any external links deep-linked or `(reference)` per the `resource-citation` standard).
- [x] 3.2 `openspec validate add-certificate-authority-orientation --strict` passes; confirm no `tracker.yaml`/objective-id change (existing `cert-issuer`/`cert-lifecycle`/`net-mesh`/`wi-spiffe` unchanged).
- [ ] 3.3 study-hub: bump the `content/oss-500` submodule, run `npm run lint:content` + `npm test` green, confirm the box and cross-links render.
