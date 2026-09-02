# ================================================================
# Outputs — IPs, IDs, Ansible inventory generation
# ================================================================

output "bastion_floating_ip" {
  description = "Bastion public IP (SSH jump host)"
  value       = openstack_networking_floatingip_v2.bastion.address
}

output "bastion_private_ip" {
  description = "Bastion private IP on mgmt network"
  value       = openstack_compute_instance_v2.bastion.access_ip_v4
}

output "lead_floating_ips" {
  description = "Lead VM public IPs"
  value       = { for k, v in openstack_networking_floatingip_v2.lead : k => v.address }
}

output "lead_private_ips" {
  description = "Lead VM private IPs on mgmt network"
  value       = { for k, v in openstack_compute_instance_v2.lead : k => v.access_ip_v4 }
}

output "moodle_private_ips" {
  description = "Moodle VM private IPs per developer network"
  value       = { for k, v in openstack_compute_instance_v2.moodle : k => v.access_ip_v4 }
}

output "lb_vip_addresses" {
  description = "Octavia LB VIP addresses per developer"
  value       = { for k, v in openstack_lb_loadbalancer_v2.moodle : k => v.vip_address }
}

output "swift_containers" {
  description = "Swift container names"
  value = concat(
    [openstack_objectstorage_container_v1.backups.name],
    [for k, v in openstack_objectstorage_container_v1.moodle_assets : v.name]
  )
}

output "developer_project_ids" {
  description = "Per-developer Keystone project IDs"
  value       = { for k, v in openstack_identity_project_v3.developer : k => v.id }
}

output "shared_project_id" {
  description = "Shared project ID"
  value       = openstack_identity_project_v3.shared.id
}

# ──────────────────────────────────────────────
# Ansible inventory (generated)
# ──────────────────────────────────────────────
output "ansible_inventory" {
  description = "Generated Ansible inventory content"
  value = templatefile("${path.module}/templates/inventory.ini.tpl", {
    bastion_ip   = openstack_networking_floatingip_v2.bastion.address
    lead_ips     = { for k, v in openstack_compute_instance_v2.lead : k => v.access_ip_v4 }
    moodle_ips   = { for k, v in openstack_compute_instance_v2.moodle : k => v.access_ip_v4 }
    ssh_key_path = abspath(var.ssh_public_key_path)
    bastion_host = openstack_networking_floatingip_v2.bastion.address
    developers   = var.developers
  })
}
