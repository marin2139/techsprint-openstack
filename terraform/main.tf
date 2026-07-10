terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.35.0"
    }
  }
}

provider "openstack" {
  user_name   = var.openstack_username
  password    = var.openstack_password
  auth_url    = var.openstack_auth_url
  tenant_name = var.openstack_project_name
  region      = var.openstack_region
  insecure    = true
}

resource "openstack_compute_instance_v2" "bastion" {
  name            = "vm-bastion"
  image_name      = "octavia-amphora-16.1-20200812.3.x86_64"
  flavor_name     = "default"
  security_groups = ["default"]
  network { uuid = "4beb2534-efb5-44b7-b6e4-aa098b0c2f9e" }
}

resource "openstack_compute_instance_v2" "lead" {
  for_each        = toset(var.leads)
  name            = "vm-lead-${each.value}"
  image_name      = "octavia-amphora-16.1-20200812.3.x86_64"
  flavor_name     = "default"
  security_groups = ["default"]
  network { uuid = "4beb2534-efb5-44b7-b6e4-aa098b0c2f9e" }
}

resource "openstack_compute_instance_v2" "moodle" {
  for_each = merge([
    for dev in var.developers : {
      "${dev}-1" = { dev_name = dev }
      "${dev}-2" = { dev_name = dev }
    }
  ]...)
  name            = "vm-moodle-${each.key}"
  image_name      = "octavia-amphora-16.1-20200812.3.x86_64"
  flavor_name     = "default-extra-disk"
  security_groups = ["default"]
  network { uuid = "4beb2534-efb5-44b7-b6e4-aa098b0c2f9e" }
}

output "done" { value = "Deployment complete" }
