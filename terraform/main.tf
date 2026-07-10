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

# Single security group - allow all for testing
resource "openstack_compute_secgroup_v2" "default" {
  name        = "sg-techsprint"
  description = "TechSprint default SG"

  rule {
    from_port   = 1
    to_port     = 65535
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 1
    to_port     = 65535
    ip_protocol = "udp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

# Bastion VM only
resource "openstack_compute_instance_v2" "bastion" {
  name            = "vm-bastion"
  image_name      = "octavia-amphora-16.1-20200812.3.x86_64"
  flavor_name     = "m1.medium"
  security_groups = ["sg-techsprint"]

  depends_on = [openstack_compute_secgroup_v2.default]
}

# Lead VMs
resource "openstack_compute_instance_v2" "lead" {
  for_each = toset(var.leads)

  name            = "vm-lead-${each.value}"
  image_name      = "octavia-amphora-16.1-20200812.3.x86_64"
  flavor_name     = "m1.medium"
  security_groups = ["sg-techsprint"]

  depends_on = [openstack_compute_secgroup_v2.default]
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
  security_groups = ["sg-techsprint"]

  depends_on = [openstack_compute_secgroup_v2.default]
}

# Outputs
output "summary" {
  value = "Deployment complete. Check 'openstack server list'"
}
