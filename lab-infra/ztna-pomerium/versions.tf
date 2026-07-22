# Common shape is templated in ../ztna-common/versions.tf.tmpl; only this stack's
# required_providers/provider block is per-model.
terraform {
  required_version = ">= 1.6"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

# Deploys into the local kind cluster. kubeconfig context comes from tfvars so the
# same code targets any cluster; no cloud account.
provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}
