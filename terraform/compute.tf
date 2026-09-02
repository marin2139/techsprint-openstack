# ================================================================
# Compute — Bastion, Lead, Moodle VMs
# ================================================================

# ──────────────────────────────────────────────
# 1. Bastion (jump host) — management network
# ──────────────────────────────────────────────
resource "openstack_compute_instance_v2" "bastion" {
  name            = "vm-bastion"
  image_name      = var.image_name
  flavor_name     = var.flavor_bastion
  key_pair        = openstack_compute_keypair_v2.techsprint.name
  security_groups = [openstack_networking_secgroup_v2.bastion.name]

  network {
    uuid = openstack_networking_network_v2.mgmt.id
  }

  metadata = merge(local.common_tags, {
    role = "bastion"
  })

  depends_on = [openstack_networking_router_interface_v2.mgmt]
}

# ──────────────────────────────────────────────
# 2. Lead VMs — management network
#    SSH access to ALL other VMs (bastion + moodle)
# ──────────────────────────────────────────────
resource "openstack_compute_instance_v2" "lead" {
  for_each        = toset(var.leads)
  name            = "vm-lead-${each.value}"
  image_name      = var.image_name
  flavor_name     = var.flavor_bastion
  key_pair        = openstack_compute_keypair_v2.techsprint.name
  security_groups = [openstack_networking_secgroup_v2.lead.name]

  network {
    uuid = openstack_networking_network_v2.mgmt.id
  }

  # Attach lead to every developer network so it can SSH to Moodle VMs
  dynamic "network" {
    for_each = toset(var.developers)
    content {
      uuid = openstack_networking_network_v2.developer[network.value].id
    }
  }

  metadata = merge(local.common_tags, {
    role = "lead"
    user = each.value
  })

  depends_on = [
    openstack_networking_router_interface_v2.mgmt,
    openstack_networking_router_interface_v2.developer,
  ]
}

# ──────────────────────────────────────────────
# 3. Moodle VMs — per-developer networks
#    2 instances per developer for HA
# ──────────────────────────────────────────────
resource "openstack_compute_instance_v2" "moodle" {
  for_each        = local.moodle_instances
  name            = "vm-moodle-${each.key}"
  image_name      = var.image_name
  flavor_name     = var.flavor_moodle           # 4 GB RAM
  key_pair        = openstack_compute_keypair_v2.techsprint.name
  security_groups = [openstack_networking_secgroup_v2.moodle.name]

  network {
    uuid = openstack_networking_network_v2.developer[each.value.developer].id
  }

  metadata = merge(local.common_tags, {
    role      = "moodle"
    developer = each.value.developer
    instance  = each.value.index
  })

  depends_on = [openstack_networking_router_interface_v2.developer]
}
