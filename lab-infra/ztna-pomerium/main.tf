# Identity-aware reverse proxy (BeyondCorp), as code. Pomerium sits in front of an
# internal web app and enforces *per-request* identity + context policy — no VPN,
# no standing network access. The IdP (Keycloak, D1) says who; Pomerium decides
# whether this request, right now, may reach this route.
# Chart values verified against the pomerium/pomerium Helm chart
# (https://artifacthub.io/packages/helm/pomerium/pomerium) — re-check the pin.

resource "helm_release" "pomerium" {
  name             = "pomerium"
  namespace        = var.namespace
  create_namespace = true
  repository       = "https://helm.pomerium.io"
  chart            = "pomerium"
  version          = "~> 46.0"

  # Routes + policy: one internal app, reachable only by an authenticated user whose
  # email is in the allowed domain. `verify` — the identity claim is the gate.
  values = [
    yamlencode({
      authenticate = {
        idp = {
          provider     = "oidc"
          url          = var.idp_provider_url
          clientID     = var.idp_client_id
          clientSecret = var.idp_client_secret
        }
      }
      config = {
        routes = [
          {
            from = "https://app.localtest.me"
            to   = "http://internal-app.default.svc.cluster.local"
            policy = [
              {
                allow = {
                  and = [
                    { domain = { is = var.allowed_domain } }
                  ]
                }
              }
            ]
          }
        ]
      }
    })
  ]
}

output "namespace" {
  value = helm_release.pomerium.namespace
}
