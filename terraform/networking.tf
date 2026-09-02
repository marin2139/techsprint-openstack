# ================================================================
# Networking — management net, per-developer nets, router, SGs
# ================================================================

# ──────────────────────────────────────────────
# SSH keypair
# ──────────────────────────────────────────────
resource "openstack_compute_keypair_v2" "techsprint" {
  name       = "${var.project_name}-key"
  public_key = file(var.ssh_public_key_path)
}

# ──────────────────────────────────────────────
# 1. Management network (bastion + lead)
# ──────────────────────────────────────────────
resource "openstack_networking_network_v2" "mgmt" {
  name           = "vnet-mgmt"
  admin_state_up = true
  tags           = [var.project_name, var.environment, "management"]
}

resource "openstack_networking_subnet_v2" "mgmt" {
  name       = "subnet-mgmt"
  network_id = openstack_networking_network_v2.mgmt.id
  cidr       = var.mgmt_cidr
  ip_version = 4

  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
  tags            = [var.project_name, var.environment]
}

# ──────────────────────────────────────────────
# 2. Per-developer networks (isolation)
# ──────────────────────────────────────────────
resource "openstack_networking_network_v2" "developer" {
  for_each       = toset(var.developers)
  name           = "vnet-${each.value}"
  admin_state_up = true
  tags           = [var.project_name, var.environment, each.value]
}

resource "openstack_networking_subnet_v2" "developer" {
  for_each   = toset(var.developers)
  name       = "subnet-${each.value}"
  network_id = openstack_networking_network_v2.developer[each.value].id
  cidr       = "10.${var.dev_cidr_prefix + index(var.developers, each.value)}.0.0/24"
  ip_version = 4

  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
  tags            = [var.project_name, var.environment, each.value]
}

# ──────────────────────────────────────────────
# 3. Router — connects all subnets + external
# ──────────────────────────────────────────────
resource "openstack_networking_router_v2" "main" {
  name                = "${var.project_name}-router"
  admin_state_up      = true
  external_network_id = var.external_network_id
  tags                = [var.project_name, var.environment]
}

resource "openstack_networking_router_interface_v2" "mgmt" {
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.mgmt.id
}

resource "openstack_networking_router_interface_v2" "developer" {
  for_each  = toset(var.developers)
  router_id = openstack_networking_router_v2.main.id
  subnet_id = openstack_networking_subnet_v2.developer[each.value].id
}

# ──────────────────────────────────────────────
# 4. Security groups
# ──────────────────────────────────────────────

# --- Bastion SG: SSH from anywhere, ICMP ---
resource "openstack_networking_secgroup_v2" "bastion" {
  name        = "sg-bastion"
  description = "Bastion — SSH from external + ICMP"
  tags        = [var.project_name, var.environment]
}

resource "openstack_networking_secgroup_rule_v2" "bastion_ssh" {
  security_group_id = openstack_networking_secgroup_v2.bastion.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "bastion_icmp" {
  security_group_id = openstack_networking_secgroup_v2.bastion.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
}

# --- Lead SG: SSH from mgmt, full internal access ---
resource "openstack_networking_secgroup_v2" "lead" {
  name        = "sg-lead"
  description = "Lead — SSH from mgmt + HTTP/HTTPS + ICMP"
  tags        = [var.project_name, var.environment]
}

resource "openstack_networking_secgroup_rule_v2" "lead_ssh_mgmt" {
  security_group_id = openstack_networking_secgroup_v2.lead.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.mgmt_cidr
}

resource "openstack_networking_secgroup_rule_v2" "lead_ssh_external" {
  security_group_id = openstack_networking_secgroup_v2.lead.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "lead_http" {
  security_group_id = openstack_networking_secgroup_v2.lead.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "lead_https" {
  security_group_id = openstack_networking_secgroup_v2.lead.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "lead_icmp" {
  security_group_id = openstack_networking_secgroup_v2.lead.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
}

# --- Moodle SG: SSH from mgmt only, HTTP/HTTPS ---
resource "openstack_networking_secgroup_v2" "moodle" {
  name        = "sg-moodle"
  description = "Moodle — SSH from mgmt + HTTP/HTTPS"
  tags        = [var.project_name, var.environment]
}

resource "openstack_networking_secgroup_rule_v2" "moodle_ssh" {
  security_group_id = openstack_networking_secgroup_v2.moodle.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.mgmt_cidr
}

resource "openstack_networking_secgroup_rule_v2" "moodle_http" {
  security_group_id = openstack_networking_secgroup_v2.moodle.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "moodle_https" {
  security_group_id = openstack_networking_secgroup_v2.moodle.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "openstack_networking_secgroup_rule_v2" "moodle_icmp" {
  security_group_id = openstack_networking_secgroup_v2.moodle.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = var.mgmt_cidr
}

# ──────────────────────────────────────────────
# 5. Floating IPs (bastion + lead)
# ──────────────────────────────────────────────
resource "openstack_networking_floatingip_v2" "bastion" {
  pool = data.openstack_networking_network_v2.external.name
  tags = [var.project_name, var.environment]
}

resource "openstack_networking_floatingip_v2" "lead" {
  for_each = toset(var.leads)
  pool     = data.openstack_networking_network_v2.external.name
  tags     = [var.project_name, var.environment]
}

resource "openstack_compute_floatingip_associate_v2" "bastion" {
  floating_ip = openstack_networking_floatingip_v2.bastion.address
  instance_id = openstack_compute_instance_v2.bastion.id
}

resource "openstack_compute_floatingip_associate_v2" "lead" {
  for_each    = toset(var.leads)
  floating_ip = openstack_networking_floatingip_v2.lead[each.value].address
  instance_id = openstack_compute_instance_v2.lead[each.value].id
}

# ──────────────────────────────────────────────
# Data sources
# ──────────────────────────────────────────────
data "openstack_networking_network_v2" "external" {
  network_id = var.external_network_id
}
