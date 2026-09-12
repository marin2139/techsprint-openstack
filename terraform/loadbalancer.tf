# ================================================================
# Load Balancing
#
# Octavia is NOT functional on this RHOSP lab (no amphora image /
# quota available), so it is not deployed as infrastructure here.
# HAProxy is configured on the bastion instead (see
# ansible/roles/bastion) — it does the same job: round-robin across
# both Moodle instances per developer with an HTTP health check, at
# no extra OpenStack-side resource cost.
#
# If Octavia becomes available on a different environment, the
# resources below (openstack_lb_loadbalancer_v2 / listener / pool /
# monitor / member, one set per developer) are the direct replacement
# — keeping them here, commented out, as a reference rather than a
# hidden intent.
# ================================================================

# resource "openstack_lb_loadbalancer_v2" "moodle" {
#   for_each      = toset(var.developers)
#   name          = "lb-moodle-${each.value}"
#   vip_subnet_id = openstack_networking_subnet_v2.developer[each.value].id
# }
#
# resource "openstack_lb_listener_v2" "moodle_http" {
#   for_each        = toset(var.developers)
#   name            = "listener-http-${each.value}"
#   protocol        = "HTTP"
#   protocol_port   = 80
#   loadbalancer_id = openstack_lb_loadbalancer_v2.moodle[each.value].id
# }
#
# resource "openstack_lb_pool_v2" "moodle_http" {
#   for_each    = toset(var.developers)
#   name        = "pool-http-${each.value}"
#   protocol    = "HTTP"
#   lb_method   = "ROUND_ROBIN"
#   listener_id = openstack_lb_listener_v2.moodle_http[each.value].id
# }
#
# resource "openstack_lb_monitor_v2" "moodle_http" {
#   for_each    = toset(var.developers)
#   name        = "monitor-http-${each.value}"
#   pool_id     = openstack_lb_pool_v2.moodle_http[each.value].id
#   type        = "HTTP"
#   url_path    = "/login/index.php"
#   port        = 80
#   delay       = 10
#   timeout     = 5
#   max_retries = 3
# }
#
# resource "openstack_lb_member_v2" "moodle_1" {
#   for_each      = toset(var.developers)
#   pool_id       = openstack_lb_pool_v2.moodle_http[each.value].id
#   address       = openstack_compute_instance_v2.moodle["${each.value}-1"].access_ip_v4
#   protocol_port = 80
#   subnet_id     = openstack_networking_subnet_v2.developer[each.value].id
# }
#
# resource "openstack_lb_member_v2" "moodle_2" {
#   for_each      = toset(var.developers)
#   pool_id       = openstack_lb_pool_v2.moodle_http[each.value].id
#   address       = openstack_compute_instance_v2.moodle["${each.value}-2"].access_ip_v4
#   protocol_port = 80
#   subnet_id     = openstack_networking_subnet_v2.developer[each.value].id
# }
