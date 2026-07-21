# Vault credential brokering — the "no shared credential" zero-trust flourish.
# Boundary fetches an SSH credential from Vault at connect time and injects it into
# the session; the end-user authenticates to Boundary and never handles the secret.
# Resource names verified against the hashicorp/boundary registry — re-check the pin.

resource "boundary_credential_store_vault" "vault" {
  name        = "lab-vault"
  description = "Vault-backed credential store for brokered SSH"
  scope_id    = boundary_scope.project.id
  address     = var.vault_addr
  token       = var.vault_token # a least-privilege Vault token; gitignored via tfvars
}

resource "boundary_credential_library_vault_generic" "ssh" {
  name                = "ssh-injected"
  description         = "Injects an SSH credential from Vault into the session"
  credential_store_id = boundary_credential_store_vault.vault.id
  path                = var.vault_ssh_path # e.g. Vault SSH secrets-engine sign/issue role
  http_method         = "POST"
}
