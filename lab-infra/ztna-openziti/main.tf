# App-embedded zero-trust overlay, as code. A client dials a private app *by name
# over the mesh* — the underlay has zero listening ports for the service, so there
# is nothing to scan or reach without an enrolled, authorized identity.
# Resource/attribute names verified against the netfoundry/ziti registry docs
# (https://registry.terraform.io/providers/netfoundry/ziti/latest/docs) — re-check
# the version pinned in versions.tf; the community provider evolves.

# --- Identities: one dials (client), one binds/hosts (the app's tunneler) ---
# Role attributes (#client / #host-app) are how policies select identities — bind
# the trust to identity, not IP. Each gets a one-time (OTT) enrollment token.
resource "ziti_identity" "client" {
  name            = "ztna-client"
  role_attributes = ["client"]
}

resource "ziti_identity" "host" {
  name            = "ztna-host"
  role_attributes = ["host-app"]
}

# --- Service configs: intercept (client side) + host (binder side) ---
# Intercept = the overlay-only address the client tunneler grabs. It exists only
# inside Ziti; the underlay never sees it.
resource "ziti_intercept_v1_config" "app" {
  name      = "private-app.intercept.v1"
  addresses = [var.intercept_address]
  protocols = ["tcp"]
  port_ranges = [
    {
      low  = var.backend_port
      high = var.backend_port
    }
  ]
}

# Host = where the binder-side tunneler forwards a dialed connection (the real app).
resource "ziti_host_v1_config" "app" {
  name     = "private-app.host.v1"
  address  = var.backend_address
  port     = var.backend_port
  protocol = "tcp"
}

# --- Service: bundles the two configs; role attribute #private-app for policies ---
resource "ziti_service" "app" {
  name            = "private-app"
  configs         = [ziti_intercept_v1_config.app.id, ziti_host_v1_config.app.id]
  role_attributes = ["private-app"]
}

# --- Authorization: who may Dial, who may Bind (least privilege by role) ---
# Only #client identities may dial #private-app; only #host-app may bind it. A
# client cannot host and the host cannot dial — split by policy, not by trust.
resource "ziti_service_policy" "dial" {
  name          = "private-app-dial"
  type          = "Dial"
  semantic      = "AnyOf"
  identityroles = ["#client"]
  serviceroles  = ["#private-app"]
}

resource "ziti_service_policy" "bind" {
  name          = "private-app-bind"
  type          = "Bind"
  semantic      = "AnyOf"
  identityroles = ["#host-app"]
  serviceroles  = ["#private-app"]
}

# --- Router reachability: let the service and identities use the edge router(s) ---
resource "ziti_service_edge_router_policy" "app" {
  name            = "private-app-serp"
  semantic        = "AnyOf"
  edgerouterroles = ["#all"]
  serviceroles    = ["#private-app"]
}

resource "ziti_edge_router_policy" "app" {
  name            = "private-app-erp"
  semantic        = "AnyOf"
  edgerouterroles = ["#all"]
  identityroles   = ["#client", "#host-app"]
}

# Enrollment tokens the tunnelers use to bootstrap identity (sensitive — one-time).
output "client_enrollment_token" {
  value     = ziti_identity.client.enrollment_token
  sensitive = true
}

output "host_enrollment_token" {
  value     = ziti_identity.host.enrollment_token
  sensitive = true
}
