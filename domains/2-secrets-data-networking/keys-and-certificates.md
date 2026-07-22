# Manage encryption keys and certificate lifecycle

Domain 2, subsection 2 (`d2-keys-certs`). Two adjacent problems: managing **encryption keys** so applications encrypt without ever holding key material (Vault's transit engine ≈ Key Vault keys), and managing the **certificate lifecycle** so TLS certs issue, renew, and rotate automatically (cert-manager ≈ Key Vault certificates). Primary lab: [d2-cert-manager](../../labs/d2-cert-manager.md); environments in [`lab-infra/secrets/`](../../lab-infra/secrets/) (transit) and [`lab-infra/certs/`](../../lab-infra/certs/).

## Provide encryption-as-a-service and manage encryption keys

*Objective: `key-transit` · OSS: Vault transit engine ≈ SC-500: Key Vault keys / encryption · Lab: [d2-cert-manager](../../labs/d2-cert-manager.md)*

Vault's **transit** engine is "encryption as a service": apps send plaintext and get ciphertext back, but **the key never leaves Vault**. All crypto happens inside Vault, so a compromised app can encrypt/decrypt while it holds a valid token but can never exfiltrate the key itself. This is the same guarantee Azure gives with Key Vault keys — operations occur inside the vault/HSM and the raw key is non-exportable.

```bash
vault secrets enable transit
vault write -f transit/keys/orders                      # create a named key (default aes256-gcm96)

# Encrypt: plaintext must be base64. Returns "vault:v1:<ciphertext>"
vault write transit/encrypt/orders plaintext=$(echo -n "4111-1111-1111-1111" | base64)
vault write transit/decrypt/orders ciphertext="vault:v1:abcd…"   # -> base64 plaintext

vault write -f transit/keys/orders/rotate               # new key version; old ciphertext (v1) still decrypts
vault write transit/rewrap/orders ciphertext="vault:v1:…"   # upgrade ciphertext to latest version, no plaintext exposure
```

The `vault:v1:` prefix versions every ciphertext, so **key rotation is seamless**: rotate the key and old data still decrypts under its old version, while `rewrap` upgrades ciphertext to the new version *without ever seeing plaintext*. A key's `min_decryption_version` and `min_encryption_version` let you retire old versions once everything is rewrapped, and `deletion_allowed`/`exportable` default to false so keys can't be casually destroyed or exfiltrated. Transit also does **convergent encryption** (identical plaintext → identical ciphertext, for equality search — but note this weakens semantic security, so use it only when you truly need deterministic lookups), signing/HMAC, and **datakey** generation (`vault write transit/datakey/plaintext/orders` returns a high-entropy data key wrapped by the Vault key — the envelope-encryption / DEK-under-KEK pattern used for encrypting large blobs locally). This same engine backs Vault auto-unseal and etcd KMS encryption (`data-encrypt`).

Failure modes: forgetting base64 encoding yields an "invalid base64" error; a token whose policy lacks `update` on `transit/encrypt/orders` fails even though it can read the key metadata; and destroying/rotating past `min_decryption_version` makes old ciphertext permanently undecryptable — the transit equivalent of deleting a Key Vault key version that data still depends on.

Against SC-500 this is **Key Vault keys / encryption**: a transit key ≈ a Key Vault key; `encrypt`/`decrypt`/`wrap`/`unwrap` ≈ the Key Vault crypto operations; datakey ≈ envelope encryption for customer-managed-key (CMK) chains on storage/disk/SQL.

Exam gotchas:

- The key never leaves Vault — apps get a *service*, not the key. "Decrypt without the key ever leaving the boundary" is transit (or Key Vault keys / Managed HSM), never a stored secret holding a key.
- Transit inputs/outputs are **base64**; forgetting to base64-encode plaintext is the classic first-time error.
- Rotation is non-breaking: old ciphertext keeps decrypting under its embedded version; `rewrap` re-encrypts to the newest version server-side without exposing plaintext.
- `datakey` is envelope encryption — Vault wraps a DEK you use locally for bulk data; only the wrapped DEK is stored.

**Resources:**
- [Transit secrets engine (docs)](https://developer.hashicorp.com/vault/docs/secrets/transit) (~20 min)
- [Encryption as a service tutorial](https://developer.hashicorp.com/vault/tutorials/encryption-as-a-service/eaas-transit) (~20 min)
- [Transit API reference (encrypt/decrypt/rewrap/datakey)](https://developer.hashicorp.com/vault/api-docs/secret/transit) (~15 min)
- [Transit key rotation & versioning tutorial](https://developer.hashicorp.com/vault/tutorials/encryption-as-a-service/eaas-transit#rotate-the-encryption-key) (~10 min)
- [NIST SP 800-57 Part 1 — cryptoperiods & key rotation](https://csrc.nist.gov/pubs/sp/800/57/pt1/r5/final) (~30 min, reference)

## Integrate an HSM as a root of trust for key material — walkthrough

*Objective: `key-hsm` · OSS: Vault HSM / PKCS#11 ≈ SC-500: Managed HSM · Lab: [d2-cert-manager](../../labs/d2-cert-manager.md) (walkthrough section)*

**Walkthrough** — a real hardware HSM (or Vault Enterprise's HSM seal) isn't practical on a laptop, so study the model rather than run it. An **HSM** (Hardware Security Module) is a tamper-resistant, FIPS 140-2/3-validated device that generates and stores key material so it *physically cannot be extracted*. As a **root of trust**, the HSM holds the top of the key hierarchy and every other key is wrapped by it. Vault integrates via **PKCS#11**: **Vault Enterprise** can use an HSM as its **seal** (auto-unseal — the HSM wraps/unwraps Vault's root key, replacing Shamir shares) and for **managed keys** (crypto operations delegated to the HSM). Vault Community edition does *not* include the PKCS#11 seal — this is an Enterprise feature.

For learning, **SoftHSM** provides a software PKCS#11 token that behaves like an HSM's API without the hardware — useful to see the `seal "pkcs11"` config shape:

```hcl
# Vault Enterprise config stanza (conceptual — Enterprise + a real/soft PKCS#11 token)
seal "pkcs11" {
  lib            = "/usr/lib/softhsm/libsofthsm2.so"
  slot           = "0"
  pin            = "1234"
  key_label      = "vault-hsm-key"
  hmac_key_label = "vault-hsm-hmac-key"
}
```

This maps to **Azure Managed HSM** (and Key Vault Premium's HSM-backed keys): a single-tenant, FIPS 140-3 Level 3 pool where keys are non-exportable and hardware-bound. SC-500 distinguishes Key Vault Premium (multi-tenant HSM, Azure RBAC) from Managed HSM (single-tenant pool, *local* RBAC) — the OSS parallel is "software transit key" vs "PKCS#11-backed key on dedicated hardware."

Exam gotchas:

- The HSM seal / PKCS#11 integration is **Vault Enterprise**, not Community — a licensing distractor mirroring Premium vs Managed HSM on Azure.
- An HSM's value is *non-extractability + hardware root of trust*, not speed. "Key must never exist outside validated hardware" → HSM/Managed HSM.
- SoftHSM is for testing the PKCS#11 wiring only — it provides no hardware tamper-resistance and no FIPS assurance.
- Using an HSM as the **seal** replaces Shamir unseal shares with hardware auto-unseal — the root key is wrapped by the HSM.

**Resources:**
- [Vault seal wrap / HSM support (Enterprise)](https://developer.hashicorp.com/vault/docs/enterprise/hsm) (~15 min)
- [PKCS#11 seal configuration](https://developer.hashicorp.com/vault/docs/configuration/seal/pkcs11) (~10 min)
- [SoftHSM2 (OpenDNSSEC) — software PKCS#11 token](https://github.com/opendnssec/SoftHSMv2) (~10 min)
- [NIST FIPS 140-3 — cryptographic module validation](https://csrc.nist.gov/pubs/fips/140-3/final) (~20 min, reference)
- [Azure Managed HSM vs Key Vault Premium (concept parallel)](https://learn.microsoft.com/azure/key-vault/managed-hsm/overview) (~10 min)

> **Which CA when.** This course runs **four certificate authorities**, each minting short-lived certs for a different job — reach for the one that owns your use case, not the one you met first:
> - **cert-manager** Issuer/ClusterIssuer → **edge/ingress and app TLS** certificate lifecycle (issue/renew/rotate into a TLS Secret) — `cert-issuer`/`cert-lifecycle`, below.
> - **Vault PKI** (the `vault` issuer / PKI engine as a CA) → **app/internal PKI**, and the CA that can *back* cert-manager's `vault` issuer — this note (`cert-issuer`, plus the `vault-*`/`key-transit` key story).
> - **Istio/Linkerd mesh CA** (`istio-ca` / Linkerd `identity`) → **east-west mesh mTLS** SVIDs minted to sidecars — `net-mesh` ([network-security.md](network-security.md)).
> - **SPIRE trust-domain CA** → **platform-agnostic SPIFFE SVIDs** for service-to-service mTLS *beyond a single mesh* (across clusters/VMs/clouds) — `wi-spiffe` ([workload-identity.md](../1-identity-governance/workload-identity.md)).

## Automate certificate issuance with cluster issuers and ACME

*Objective: `cert-issuer` · OSS: cert-manager ≈ SC-500: Key Vault certificates · Lab: [d2-cert-manager](../../labs/d2-cert-manager.md)*

**cert-manager** is the Kubernetes-native certificate controller: you declare a `Certificate` object and it obtains, stores (as a TLS Secret), and renews the cert automatically. Sources of trust are modeled as **Issuers** (namespaced) or **ClusterIssuers** (cluster-wide): `selfSigned`, `ca` (issue from your own CA cert/key), `acme` (Let's Encrypt and any ACME CA, via HTTP-01 or DNS-01 challenge), and `vault` (issue from Vault's PKI engine). On a local kind cluster you use a self-signed or CA issuer because ACME/Let's Encrypt needs a public, internet-reachable domain.

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: oss500-ca
spec:
  ca:
    secretName: oss500-ca-keypair      # a CA cert+key created by a bootstrap selfSigned issuer
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-tls
  namespace: oss500-apps
spec:
  secretName: app-tls                  # cert-manager writes the signed cert+key here
  duration: 2160h                      # 90d
  renewBefore: 360h                    # renew 15d before expiry (cert-lifecycle)
  dnsNames:
    - app.oss500.local
  issuerRef:
    name: oss500-ca
    kind: ClusterIssuer
```

Under the hood cert-manager expands a `Certificate` into a chain of resources — `CertificateRequest` → an `Order` and one or more `Challenge` objects for ACME — which is exactly what you inspect when issuance is stuck (`kubectl describe order`/`challenge`). The **ACME** protocol (RFC 8555) proves domain control two ways: **HTTP-01** serves a token at `/.well-known/acme-challenge/` (needs port 80 reachable, one hostname, no wildcards) while **DNS-01** publishes a `_acme-challenge` TXT record (works behind a firewall and supports **wildcards**, but needs DNS-provider credentials). cert-manager reconciles all this into a signed cert in the `app-tls` Secret, which an Ingress then references for TLS (`net-ingress`). This is the OSS equivalent of **Key Vault certificates**: an issuer ≈ Key Vault's integrated CA, the `Certificate` ≈ a Key Vault certificate object with a policy, and ACME auto-issuance ≈ Key Vault's fully-automatic renewal with an integrated CA.

For internal trust, cert-manager's **trust-manager** distributes CA bundles to workloads so they trust your private CA, and the `vault` issuer lets Vault's **PKI engine** be the CA — unifying the key story (`key-transit`/`vault-*`) with the certificate story.

Exam gotchas:

- **Issuer** is namespaced; **ClusterIssuer** is cluster-wide. A Certificate referencing an Issuer in another namespace fails — scope must match.
- ACME (Let's Encrypt) needs a publicly reachable domain to solve HTTP-01/DNS-01 — locally you use `selfSigned` or `ca`, not ACME.
- cert-manager writes the cert+key into a Kubernetes **TLS Secret** (base64, in etcd) — encrypt etcd (`data-encrypt`) to protect the private key at rest.
- A `Certificate` is desired state; cert-manager (the controller) does the work — like Key Vault's certificate object + policy driving auto-issuance.
- **HTTP-01 can't do wildcards; DNS-01 can.** A `*.oss500.local` request forces DNS-01 (and DNS-provider creds) — a common exam/lab distinction.

**Resources:**
- [cert-manager Issuer configuration](https://cert-manager.io/docs/configuration/) (~15 min)
- [cert-manager Certificate resource](https://cert-manager.io/docs/usage/certificate/) (~15 min)
- [cert-manager ACME issuer & HTTP-01/DNS-01 challenges](https://cert-manager.io/docs/configuration/acme/) (~20 min)
- [RFC 8555 — Automatic Certificate Management Environment (ACME)](https://datatracker.ietf.org/doc/html/rfc8555) (~30 min, reference)
- [Let's Encrypt — how it works / challenge types](https://letsencrypt.org/how-it-works/) (~10 min)

## Manage certificate renewal, rotation, and revocation

*Objective: `cert-lifecycle` · OSS: cert-manager ≈ SC-500: Certificate lifecycle management · Lab: [d2-cert-manager](../../labs/d2-cert-manager.md)*

cert-manager's biggest win is **automatic renewal**: `spec.duration` sets the cert's validity and `spec.renewBefore` (or `renewBeforePercentage`) sets how early to re-issue. The controller re-requests from the issuer and rewrites the TLS Secret in place *before* expiry, so short-lived certs (90 days for Let's Encrypt, or much shorter internally) rotate with zero human action. You can force an immediate renewal for testing or after a suspected compromise with the CLI:

```bash
cmctl renew app-tls -n oss500-apps          # force reissue now (cmctl = cert-manager CLI)
cmctl status certificate app-tls -n oss500-apps
kubectl get certificate -A                   # READY=True, and the renewal timestamp
```

**Rotation** is just renewal producing a new key/cert into the same Secret; workloads that mount the Secret pick it up (ingress-nginx and most controllers reload on Secret change, though a bare pod mounting the Secret as a volume may cache it until restart — a real gotcha). **Revocation** is issuer-dependent: with ACME you revoke at the CA (`certbot revoke` / ACME `revoke-cert`); with a private CA you publish a **CRL** (Certificate Revocation List) or run **OCSP**; cert-manager itself doesn't run a CRL — you rotate to a fresh cert and revoke the old one at the CA. Because CRL/OCSP checking is inconsistently enforced by clients, the modern posture (and the exam's) is **short-lived certificates with automated renewal** so an attacker's window is bounded by expiry rather than by revocation propagation.

This is **certificate lifecycle management** as SC-500 frames it for Key Vault: lifetime actions that auto-renew at N% of lifetime or D days before expiry, fully automatic with an integrated CA. cert-manager's `renewBefore`/`duration` ≈ Key Vault certificate policy lifetime actions.

Exam gotchas:

- Renewal is automatic and driven by `renewBefore`/`duration` — you don't script expiry checks; the controller re-issues and rewrites the Secret in place.
- Revocation isn't a cert-manager primitive — you revoke at the **issuing CA** (CRL/OCSP/ACME revoke) and rotate to a new cert. Short durations shrink the exposure window.
- Prefer short-lived certs with automated renewal over long-lived certs you must remember to revoke — same lesson as dynamic secrets vs static passwords.
- The renewed cert lands in the same TLS Secret; downstream consumers must reload on Secret change (ingress-nginx does).

Exam gotchas (additional):

- **cmctl renew** forces an immediate reissue for testing/incident response; it does not revoke the old cert — do that at the CA.
- The renewed key/cert lands in the **same Secret name**; consumers must reload on change or be restarted.
- **CRL vs OCSP**: CRL is a periodically published revocation *list* (bulk, cacheable, can be stale); OCSP is a *per-cert* real-time query (fresher, adds a dependency). Know both for the exam.

**Resources:**
- [cert-manager renewal & the cmctl CLI](https://cert-manager.io/docs/reference/cmctl/) (~15 min)
- [Certificate lifecycle / renewal reference](https://cert-manager.io/docs/usage/certificate/#renewal) (~10 min)
- [cert-manager troubleshooting issuance (Order/Challenge)](https://cert-manager.io/docs/troubleshooting/) (~15 min)
- [RFC 5280 — X.509 certificates & CRL profile](https://datatracker.ietf.org/doc/html/rfc5280) (~30 min, reference)
- [RFC 6960 — OCSP](https://datatracker.ietf.org/doc/html/rfc6960) (~20 min, reference)

## Summary

| Objective | Takeaway |
|---|---|
| `key-transit` | Transit engine = encryption-as-a-service; key never leaves Vault; versioned `vault:vN:` ciphertext, non-breaking rotation, rewrap, datakey envelope encryption |
| `key-hsm` | HSM = non-extractable hardware root of trust via PKCS#11; Vault **Enterprise** seal/managed keys ≈ Azure Managed HSM (walkthrough; SoftHSM for testing) |
| `cert-issuer` | cert-manager Issuer/ClusterIssuer (selfSigned/ca/acme/vault) + `Certificate` → auto-issued TLS Secret; ACME needs a public domain |
| `cert-lifecycle` | `duration`+`renewBefore` drive automatic renewal/rotation; revoke at the CA (CRL/OCSP); `cmctl renew` forces reissue |
