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

# SSH Key Pair
resource "openstack_compute_keypair_v2" "techsprint" {
  name       = "techsprint-key"
  public_key = file("${path.module}/../ssh_key.pub")
}

# Get external network
data "openstack_networking_network_v2" "external" {
  name = "provider-storage"
}

# Create networks per developer
resource "openstack_networking_network_v2" "developer" {
  for_each       = toset(var.developers)
  name           = "vnet-${each.value}"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "developer" {
  for_each = toset(var.developers)

  name            = "subnet-${each.value}"
  network_id      = openstack_networking_network_v2.developer[each.value].id
  cidr            = "10.${100 + index(var.developers, each.value)}.0.0/24"
  gateway_ip      = "10.${100 + index(var.developers, each.value)}.0.1"
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

# Management network
resource "openstack_networking_network_v2" "management" {
  name           = "vnet-management"
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "management" {
  name            = "subnet-management"
  network_id      = openstack_networking_network_v2.management.id
  cidr            = "10.0.0.0/24"
  gateway_ip      = "10.0.0.1"
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

# Router
resource "openstack_networking_router_v2" "techsprint" {
  name                = "router-techsprint"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

# Router interfaces
resource "openstack_networking_router_interface_v2" "developer" {
  for_each = toset(var.developers)

  router_id = openstack_networking_router_v2.techsprint.id
  subnet_id = openstack_networking_subnet_v2.developer[each.value].id
}

resource "openstack_networking_router_interface_v2" "management" {
  router_id = openstack_networking_router_v2.techsprint.id
  subnet_id = openstack_networking_subnet_v2.management.id
}

# Security Groups
resource "openstack_compute_secgroup_v2" "bastion" {
  name        = "sg-bastion"
  description = "Bastion security group"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_compute_secgroup_v2" "developer" {
  for_each = toset(var.developers)

  name        = "sg-dev-${each.value}"
  description = "Developer ${each.value} security group"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 443
    to_port     = 443
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_compute_secgroup_v2" "lead" {
  name        = "sg-lead"
  description = "Lead security group"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

# Bastion VM
resource "openstack_compute_instance_v2" "bastion" {
  name           = "vm-bastion"
  image_name     = "rhe18"
  flavor_name    = "m1.medium"
  key_pair       = openstack_compute_keypair_v2.techsprint.name
  security_group = openstack_compute_secgroup_v2.bastion.name

  network {
    uuid = openstack_networking_network_v2.management.id
  }
}

# Floating IP for Bastion
resource "openstack_networking_floatingip_v2" "bastion" {
  pool = data.openstack_networking_network_v2.external.name
}

resource "openstack_compute_floatingip_associate_v2" "bastion" {
  floating_ip = openstack_networking_floatingip_v2.bastion.address
  instance_id = openstack_compute_instance_v2.bastion.id
}

# Lead VMs
resource "openstack_compute_instance_v2" "lead" {
  for_each = toset(var.leads)

  name           = "vm-lead-${each.value}"
  image_name     = "rhe18"
  flavor_name    = "m1.medium"
  key_pair       = openstack_compute_keypair_v2.techsprint.name
  security_group = openstack_compute_secgroup_v2.lead.name

  network {
    uuid = openstack_networking_network_v2.management.id
  }
}

# Moodle VMs
resource "openstack_compute_instance_v2" "moodle" {
  for_each = merge([
    for dev in var.developers : {
      "${dev}-1" = {
        dev_name = dev
        instance = 1
      }
      "${dev}-2" = {
        dev_name = dev
        instance = 2
      }
    }
  ]...)

  name           = "vm-moodle-${each.key}"
  image_name     = "rhe18"
  flavor_name    = "m1.large"
  key_pair       = openstack_compute_keypair_v2.techsprint.name
  security_group = openstack_compute_secgroup_v2.developer[each.value.dev_name].name

  network {
    uuid = openstack_networking_network_v2.developer[each.value.dev_name].id
  }
}

# Outputs
output "bastion_ip" {
  value = openstack_networking_floatingip_v2.bastion.address
}

output "bastion_internal_ip" {
  value = openstack_compute_instance_v2.bastion.access_ip_v4
}

output "moodle_instances" {
  value = {
    for key, instance in openstack_compute_instance_v2.moodle :
    key => instance.access_ip_v4
  }
}

output "lead_instances" {
  value = {
    for key, instance in openstack_compute_instance_v2.lead :
    key => instance.access_ip_v4
  }
}

output "ansible_inventory" {
  value = <<EOF
[bastion]
bastion ansible_host=${openstack_networking_floatingip_v2.bastion.address}

[moodle]
%{for key, instance in openstack_compute_instance_v2.moodle~}
${key} ansible_host=${instance.access_ip_v4} ansible_user=root
%{endfor~}

[lead]
%{for key, instance in openstack_compute_instance_v2.lead~}
${key} ansible_host=${instance.access_ip_v4} ansible_user=root
%{endfor~}

[all:vars]
ansible_ssh_private_key_file=../ssh_key
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
}
