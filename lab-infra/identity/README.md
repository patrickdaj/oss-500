# identity — Keycloak (OIDC/SAML identity provider)

Environment for the Domain 1 identity labs ([d1-keycloak-sso-mfa](../../labs/d1-keycloak-sso-mfa.md) and [d1-keycloak-conditional-access](../../labs/d1-keycloak-conditional-access.md)). Keycloak is the open-source stand-in for Microsoft Entra ID — realms, users, groups, clients, MFA, conditional flows, brokering, and consent.

**Objectives:** `kc-deploy`, `kc-mfa`, `kc-ca`, `kc-clients`, `kc-federation`, `kc-consent`
**Footprint:** ~1.5 GB (Keycloak + PostgreSQL). **Up:** ~3–5 min (image pull + DB init).

Deploys Keycloak via the bitnami Helm chart with a bundled PostgreSQL subchart into the `oss500-identity` namespace. That namespace enforces the **restricted** Pod Security Standard, so [`values.yaml`](values.yaml) sets a hardened `securityContext` (non-root, no privilege escalation, `drop: ALL`, `seccompProfile: RuntimeDefault`) on both pods — the IdP models the pod hardening the rest of the course teaches. The admin password is supplied out-of-band via a gitignored `admin-password.env` and injected as the `keycloak-admin` Secret, so no credential lands in a manifest.

```bash
cp admin-password.env.example admin-password.env   # set KEYCLOAK_ADMIN_PASSWORD
./up.sh
# add to /etc/hosts:  127.0.0.1  keycloak.oss500.local
```

**Verify**
```bash
# Admin console reachable (browser): http://keycloak.oss500.local:8080/admin  (user: admin)
# Or port-forward, then hit the OIDC discovery document:
kubectl -n oss500-identity port-forward svc/keycloak 8080:80 &
curl -s http://localhost:8080/realms/master/.well-known/openid-configuration | head

# kcadm: authenticate and list realms/clients (proves the IdP is administrable)
kubectl -n oss500-identity exec deploy/keycloak -- \
  /opt/bitnami/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 --realm master --user admin --password "$KEYCLOAK_ADMIN_PASSWORD"
kubectl -n oss500-identity exec deploy/keycloak -- /opt/bitnami/keycloak/bin/kcadm.sh get realms --fields realm,enabled
```

The `oss500` realm, users, groups, clients, MFA flows, brokering, and consent are created **during the labs** (via `kcadm.sh` and the admin console) so you perform the modelling yourself — see the two lab guides.

**Teardown:** `./down.sh` (uninstalls the release, deletes the admin secret and the PostgreSQL PVCs). The shared `oss500-identity` namespace is left in place.
