# Common shape is templated in ../ztna-common/versions.tf.tmpl; only this stack's
# required_providers/provider block is per-model.
terraform {
  required_version = ">= 1.6"
  required_providers {
    boundary = {
      source  = "hashicorp/boundary"
      version = "~> 1.2"
    }
  }
}

# The Boundary controller you're managing. Auth via a password auth-method login.
# addr + credentials come from tfvars/env (gitignored) — never committed.
provider "boundary" {
  addr                   = var.boundary_addr
  auth_method_login_name = var.boundary_login_name
  auth_method_password   = var.boundary_password
}
