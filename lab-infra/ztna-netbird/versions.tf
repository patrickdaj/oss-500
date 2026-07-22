# Common shape is templated in ../ztna-common/versions.tf.tmpl; only this stack's
# required_providers/provider block is per-model.
terraform {
  required_version = ">= 1.6"
  required_providers {
    netbird = {
      source  = "netbirdio/netbird"
      version = "~> 0.0.9"
    }
  }
}

# Talks to the NetBird management API. For the local lab this is a self-hosted
# control plane (docker compose); management_url + token come from tfvars.
provider "netbird" {
  management_url = var.management_url
  token          = var.netbird_token
}
