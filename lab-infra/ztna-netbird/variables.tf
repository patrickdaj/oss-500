variable "management_url" {
  type        = string
  default     = "http://localhost:33073"
  description = "NetBird management API URL (self-hosted control plane; $0, local)."
}

variable "netbird_token" {
  type        = string
  sensitive   = true
  description = "NetBird PAT / service-user token — gitignored via tfvars, never committed."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "Port the admin group is allowed to reach on the servers group."
}
