# ================================================================
# Storage — Cinder volumes, Swift containers, Manila file shares
# ================================================================

# ──────────────────────────────────────────────
# 1. Cinder data volumes (one per Moodle VM)
# ──────────────────────────────────────────────
resource "openstack_blockstorage_volume_v3" "moodle_data" {
  for_each    = local.moodle_instances
  name        = "vol-data-${each.key}"
  size        = var.cinder_volume_size
  description = "Moodle data volume for ${each.key}"

  metadata = merge(local.common_tags, {
    role      = "moodle-data"
    developer = each.value.developer
  })
}

resource "openstack_compute_volume_attach_v2" "moodle_data" {
  for_each    = local.moodle_instances
  instance_id = openstack_compute_instance_v2.moodle[each.key].id
  volume_id   = openstack_blockstorage_volume_v3.moodle_data[each.key].id
}

# ──────────────────────────────────────────────
# 2. Swift object storage containers
#    - Backups container (shared)
#    - Per-developer Moodle assets container
# ──────────────────────────────────────────────
resource "openstack_objectstorage_container_v1" "backups" {
  name = "${var.project_name}-backups"

  metadata = {
    project     = var.project_name
    environment = var.environment
    purpose     = "database-and-config-backups"
  }
}

resource "openstack_objectstorage_container_v1" "moodle_assets" {
  for_each = toset(var.developers)
  name     = "${var.project_name}-assets-${each.value}"

  metadata = {
    project     = var.project_name
    environment = var.environment
    developer   = each.value
    purpose     = "moodle-uploaded-files"
  }
}

# ──────────────────────────────────────────────
# 3. Manila shared filesystem
#    Shared moodledata directory across HA pair
# ──────────────────────────────────────────────
# NOTE: Manila requires a share network and share type to be
# pre-configured on the RHOSP cluster. If Manila is not available,
# comment out this section and use Cinder + rsync instead.

# data "openstack_sharedfilesystem_sharenetwork_v2" "default" {
#   name = "default-share-network"
# }

# resource "openstack_sharedfilesystem_share_v2" "moodledata" {
#   for_each         = toset(var.developers)
#   name             = "manila-moodledata-${each.value}"
#   share_proto      = var.manila_share_protocol
#   size             = var.manila_share_size
#   description      = "Shared Moodle data for ${each.value} HA pair"
#   share_network_id = data.openstack_sharedfilesystem_sharenetwork_v2.default.id
#
#   metadata = merge(local.common_tags, {
#     developer = each.value
#   })
# }
#
# resource "openstack_sharedfilesystem_share_access_v2" "moodledata" {
#   for_each     = toset(var.developers)
#   share_id     = openstack_sharedfilesystem_share_v2.moodledata[each.value].id
#   access_type  = "ip"
#   access_to    = openstack_networking_subnet_v2.developer[each.value].cidr
#   access_level = "rw"
# }
