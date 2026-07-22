variable "kubeconfig_path" {
  type        = string
  default     = "~/.kube/config"
  description = "Path to the kubeconfig for the local kind cluster."
}

variable "kube_context" {
  type        = string
  default     = "kind-oss500"
  description = "kubeconfig context of the target cluster."
}

variable "namespace" {
  type        = string
  default     = "ztna-pomerium"
  description = "Namespace for the Pomerium release."
}

# OIDC (Keycloak from Domain 1) — Pomerium is the identity-aware proxy; the IdP is
# the source of truth for *who*. Secrets come from tfvars (gitignored).
variable "idp_provider_url" {
  type        = string
  description = "OIDC issuer URL, e.g. https://keycloak.localtest.me/realms/oss500."
}

variable "idp_client_id" {
  type        = string
  description = "OIDC client id Pomerium authenticates with."
}

variable "idp_client_secret" {
  type        = string
  sensitive   = true
  description = "OIDC client secret — gitignored via tfvars, never committed."
}

# Who is allowed through. The whole point: per-request identity policy, not an
# all-or-nothing network route.
variable "allowed_domain" {
  type        = string
  default     = "oss500.local"
  description = "Email domain permitted to reach the internal app (identity policy)."
}
