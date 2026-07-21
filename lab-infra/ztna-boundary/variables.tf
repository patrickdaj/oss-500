variable "boundary_addr" {
  type        = string
  description = "Boundary controller address, e.g. http://127.0.0.1:9200 (dev) or your HCP/self-hosted URL."
}
variable "boundary_login_name" {
  type = string
}
variable "boundary_password" {
  type      = string
  sensitive = true
}

# The target we broker access to (e.g. a Linux host on the trust subnet).
variable "target_host_address" {
  type        = string
  description = "IP/DNS of the private host Boundary will broker SSH to."
}
variable "target_port" {
  type    = number
  default = 22
}
variable "app_user_password" {
  type        = string
  sensitive   = true
  description = "Password for the demo end-user account created in Boundary."
}

# Vault (for credential brokering — Boundary talks to Vault; no Vault TF provider needed).
variable "vault_addr" {
  type        = string
  description = "Vault address Boundary uses to fetch/inject the SSH credential."
}
variable "vault_token" {
  type        = string
  sensitive   = true
  description = "Vault token for the Boundary credential store (least-privilege, gitignored)."
}
variable "vault_ssh_path" {
  type        = string
  default     = "ssh/sign/boundary"
  description = "Vault path (e.g. SSH secrets engine sign role) the credential library reads."
}
