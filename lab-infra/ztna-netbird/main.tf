# WireGuard mesh with identity ACLs, as code. Devices join an encrypted peer-to-peer
# mesh via a self-hosted control plane; access between them is governed by *group
# policy*, not by being "on the network". Default is deny — a peer sees only what a
# policy explicitly allows, so joining the mesh grants no lateral reach on its own.
# Resource/attribute names verified against the netbirdio/netbird registry docs
# (https://registry.terraform.io/providers/netbirdio/netbird/latest/docs) — re-check
# the version pinned in versions.tf.

# --- Groups: identity buckets peers land in at enrollment (not IP ranges) ---
resource "netbird_group" "admins" {
  name = "admins"
}

resource "netbird_group" "servers" {
  name = "servers"
}

# --- Setup keys: enroll a device straight into its group (identity at join time) ---
# Reusable so several devices can join; auto_groups pins the identity/ACL bucket.
resource "netbird_setup_key" "admin" {
  name           = "admin-laptops"
  type           = "reusable"
  expiry_seconds = 86400
  auto_groups    = [netbird_group.admins.id]
}

resource "netbird_setup_key" "server" {
  name           = "server-fleet"
  type           = "reusable"
  expiry_seconds = 86400
  auto_groups    = [netbird_group.servers.id]
}

# --- Policy: admins may reach servers on SSH — and nothing else is implied ---
# One-directional (bidirectional = false): servers cannot initiate back to admins,
# and server-to-server lateral movement is not granted by this policy. Least
# privilege by identity group, the ZTNA mesh proof.
resource "netbird_policy" "admin_ssh" {
  name    = "admins-ssh-to-servers"
  enabled = true

  rule {
    name          = "admin-ssh"
    action        = "accept"
    protocol      = "tcp"
    bidirectional = false
    enabled       = true
    sources       = [netbird_group.admins.id]
    destinations  = [netbird_group.servers.id]
    ports         = [tostring(var.ssh_port)]
  }
}

output "admin_setup_key" {
  value     = netbird_setup_key.admin.key
  sensitive = true
}

output "server_setup_key" {
  value     = netbird_setup_key.server.key
  sensitive = true
}
