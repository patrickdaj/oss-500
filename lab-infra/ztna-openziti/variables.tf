variable "ziti_mgmt_host" {
  type        = string
  description = "OpenZiti edge-management API, e.g. https://127.0.0.1:1280/edge/management/v1 (quickstart)."
}

variable "ziti_username" {
  type        = string
  description = "Ziti admin login (quickstart default: admin)."
}

variable "ziti_password" {
  type        = string
  sensitive   = true
  description = "Ziti admin password — gitignored via tfvars, never committed."
}

# The real backend the binder-side tunneler forwards to (stays on the trust side;
# nothing about it is exposed inbound — the overlay dials it, not the network).
variable "backend_address" {
  type        = string
  default     = "127.0.0.1"
  description = "Address the hosting tunneler forwards the service to (the private app)."
}

variable "backend_port" {
  type        = number
  default     = 8080
  description = "Port of the private backend app."
}

# The name clients dial. It resolves *inside* the overlay only — it is not a real
# DNS name and never touches the underlay, so there is nothing to port-scan.
variable "intercept_address" {
  type        = string
  default     = "private-app.ziti"
  description = "Overlay-only hostname the client dials (intercepted by its tunneler)."
}
