terraform {
  required_version = ">= 1.3.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }
}

# ──────────────────────────────────────────────
# Provider — authenticates as admin to manage
# cross-project resources (identity, quotas).
# ──────────────────────────────────────────────
provider "openstack" {
  auth_url    = var.openstack_auth_url
  user_name   = var.admin_username
  password    = var.admin_password
  tenant_name = var.admin_project
  domain_name = var.admin_domain
  region      = var.openstack_region
  insecure    = true
}

# ──────────────────────────────────────────────
# Local helpers
# ──────────────────────────────────────────────
locals {
  all_users = concat(var.developers, var.leads)

  # Moodle instances: 2 per developer
  moodle_instances = merge([
    for dev in var.developers : {
      "${dev}-1" = { developer = dev, index = 1 }
      "${dev}-2" = { developer = dev, index = 2 }
    }
  ]...)

  common_tags = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}
