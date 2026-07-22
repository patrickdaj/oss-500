terraform {
  required_version = ">= 1.6"
  required_providers {
    ziti = {
      source  = "netfoundry/ziti"
      version = "~> 1.0"
    }
  }
}

# Talks to the OpenZiti controller's edge-management API. For the local lab this is
# a `ziti edge quickstart` controller; addr + admin creds come from tfvars (gitignored).
provider "ziti" {
  host     = var.ziti_mgmt_host
  username = var.ziti_username
  password = var.ziti_password
}
