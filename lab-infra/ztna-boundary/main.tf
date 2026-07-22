# Zero-trust access to one host, defined entirely as code.
# Resource/attribute names verified against the hashicorp/boundary registry docs
# (https://registry.terraform.io/providers/hashicorp/boundary/latest/docs) — the
# provider evolves, so re-check the version pinned in versions.tf.

# --- Scopes: org -> project (zero-trust: resources organized, not a flat network) ---
resource "boundary_scope" "org" {
  scope_id                 = "global"
  name                     = "modern-security-lab"
  description              = "ZTNA-as-code demo org"
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "boundary_scope" "project" {
  scope_id    = boundary_scope.org.id
  name        = "private-apps"
  description = "Private apps reachable only by brokered session"
}

# --- Identity: a password auth-method, one end-user account, mapped to a user ---
resource "boundary_auth_method" "password" {
  scope_id = boundary_scope.org.id
  type     = "password"
}

resource "boundary_account_password" "app_user" {
  auth_method_id = boundary_auth_method.password.id
  login_name     = "appuser"
  password       = var.app_user_password
}

resource "boundary_user" "app_user" {
  scope_id    = boundary_scope.org.id
  name        = "appuser"
  account_ids = [boundary_account_password.app_user.id]
}

# --- Target: a static host catalog -> host -> host set -> tcp target ---
resource "boundary_host_catalog_static" "hosts" {
  name     = "private-hosts"
  scope_id = boundary_scope.project.id
}

resource "boundary_host_static" "app" {
  name            = "app-host"
  host_catalog_id = boundary_host_catalog_static.hosts.id
  address         = var.target_host_address
}

resource "boundary_host_set_static" "app" {
  name            = "app-hosts"
  host_catalog_id = boundary_host_catalog_static.hosts.id
  host_ids        = [boundary_host_static.app.id]
}

resource "boundary_target" "ssh" {
  name            = "app-ssh"
  description     = "SSH to the private host, brokered per-session with Vault-injected creds"
  type            = "tcp"
  scope_id        = boundary_scope.project.id
  default_port    = var.target_port
  host_source_ids = [boundary_host_set_static.app.id]

  # Vault injects the SSH credential at connect time — the user never sees it. [credentials-vault.tf]
  injected_application_credential_source_ids = [boundary_credential_library_vault.ssh.id]
}

# --- Authorization: least-privilege grant — this user may connect to this target only ---
resource "boundary_role" "connect" {
  name        = "connect-app-ssh"
  description = "Authorize the app user to establish sessions to the SSH target"
  scope_id    = boundary_scope.project.id
  grant_strings = [
    "ids=${boundary_target.ssh.id};actions=authorize-session",
  ]
  principal_ids = [boundary_user.app_user.id]
}

output "target_id" {
  value = boundary_target.ssh.id
}
