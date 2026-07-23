# Vault credential injection — the "no shared credential" zero-trust flourish.
# Boundary fetches an SSH credential from Vault at connect time and injects it into
# the session (the target is attached via injected_application_credential_source_ids
# in main.tf); the end-user authenticates to Boundary and never handles the secret.
# Resource names verified against the hashicorp/boundary registry — re-check the pin.

resource "boundary_credential_store_vault" "vault" {
  name        = "lab-vault"
  description = "Vault-backed credential store for injected SSH creds"
  scope_id    = boundary_scope.project.id
  address     = var.vault_addr
  token       = var.vault_token # a least-privilege Vault token; gitignored via tfvars
}

resource "boundary_credential_library_vault" "ssh" {
  name                = "ssh-injected"
  description         = "Injects an SSH credential from Vault into the session"
  credential_store_id = boundary_credential_store_vault.vault.id
  path                = var.vault_ssh_path # Vault SSH secrets-engine sign role (ssh/sign/boundary)
  http_method         = "POST"
}
