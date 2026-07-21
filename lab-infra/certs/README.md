# certs — cert-manager (+ in-cluster CA)

Automated certificate issuance, renewal, and rotation for the cluster. Backs the
lab [d2-cert-manager](../../labs/d2-cert-manager.md).
**SC-500 correspondence:** Azure Key Vault certificates + certificate lifecycle
management (auto-renewal, lifetime actions).

**Objectives:** `cert-issuer`, `cert-lifecycle` (the `key-hsm` HSM-root-of-trust piece is a **walkthrough** section in the lab)

**Footprint:** cert-manager controller + webhook + cainjector ≈ 150–250 MB, 3 pods.

Installs cert-manager, then builds a two-step CA chain: a `selfSigned` ClusterIssuer
bootstraps a root **CA Certificate**, and a `ca-issuer` ClusterIssuer signs leaf
certs from it — the open-source analogue of a Key Vault backed by a private CA. The
demo leaf cert uses a deliberately short `duration: 24h` / `renewBefore: 12h` so
auto-renewal is observable within a study session.

```bash
./up.sh                                  # cert-manager + selfsigned/ca issuers
kubectl apply -f example-certificate.yaml # the short-lived demo leaf cert
```

**Verify**
```bash
# cert-issuer: the CA and issuers are Ready
kubectl get clusterissuer selfsigned-issuer ca-issuer
kubectl -n oss500-secrets get certificate oss500-ca

# cert-lifecycle: the leaf cert was issued into a TLS Secret
kubectl -n oss500-apps get certificate demo-tls
kubectl -n oss500-apps get secret demo-tls -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -noout -subject -enddate

# cert-lifecycle: inspect / force renewal timing
cmctl status certificate demo-tls -n oss500-apps
cmctl renew demo-tls -n oss500-apps
```

**Teardown**
```bash
./down.sh        # deletes certs, issuers, CA secret; helm uninstall cert-manager
```

> `cmctl` is the cert-manager CLI: https://cert-manager.io/docs/reference/cmctl/
