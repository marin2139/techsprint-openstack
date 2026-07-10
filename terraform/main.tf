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

# Bastion VM - use default security group
resource "openstack_compute_instance_v2" "bastion" {
  name            = "vm-bastion"
  image_name      = "octavia-amphora-16.1-20200812.3.x86_64"
  flavor_name     = "m1.medium"
  security_groups = ["default"]
}

# Lead VMs
resource "openstack_compute_instance_v2" "lead" {
  for_each = toset(var.leads)

  name            = "vm-lead-${each.value}"
  image_name      = "octavia-amphora-16.1-20200812.3.x86_64"
  flavor_name     = "m1.medium"
  security_groups = ["default"]
}

# Moodle VMs
resource "openstack_compute_instance_v2" "moodle" {
  for_each = merge([
    for dev in var.developers : {
      "${dev}-1" = { dev_name = dev }
      "${dev}-2" = { dev_name = dev }
    }
  ]...)

  name            = "vm-moodle-${each.key}"
  image_name      = "octavia-amphora-16.1-20200812.3.x86_64"
  flavor_name     = "m1.large"
  security_groups = ["default"]
}

# Outputs
output "deployment_info" {
  value = "Deployment complete. Run: openstack server list"
}

output "bastion" {
  value = openstack_compute_instance_v2.bastion.name
}

output "leads" {
  value = [for k in openstack_compute_instance_v2.lead : k.name]
}

output "moodles" {
  value = [for k in openstack_compute_instance_v2.moodle : k.name]
}
