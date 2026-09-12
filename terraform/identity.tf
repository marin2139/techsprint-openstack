# ================================================================
# Keystone Identity — projects, groups, users, role assignments
# ================================================================

# ──────────────────────────────────────────────
# 1. Shared project (lead visibility)
# ──────────────────────────────────────────────
resource "openstack_identity_project_v3" "shared" {
  name        = "${var.project_name}-shared"
  description = "Shared project for leads and cross-cutting resources"
  tags        = [var.project_name, var.environment]
}

# ──────────────────────────────────────────────
# 2. Per-developer projects (tenant isolation)
# ──────────────────────────────────────────────
resource "openstack_identity_project_v3" "developer" {
  for_each    = toset(var.developers)
  name        = "${var.project_name}-${each.value}"
  description = "Isolated tenant for developer ${each.value}"
  tags        = [var.project_name, var.environment, each.value]
}

# ──────────────────────────────────────────────
# 3. Keystone groups
# ──────────────────────────────────────────────
resource "openstack_identity_group_v3" "leads" {
  name        = "${var.project_name}-leads"
  description = "DevOps leads — admin on shared, reader on dev projects"
}

resource "openstack_identity_group_v3" "developers" {
  name        = "${var.project_name}-developers"
  description = "Developers — member only on their own project"
}

# ──────────────────────────────────────────────
# 4. Users
# ──────────────────────────────────────────────
resource "openstack_identity_user_v3" "lead" {
  for_each          = toset(var.leads)
  name              = each.value
  default_project_id = openstack_identity_project_v3.shared.id
  password          = var.default_user_password
  description       = "DevOps Lead"
}

resource "openstack_identity_user_v3" "developer" {
  for_each          = toset(var.developers)
  name              = each.value
  default_project_id = openstack_identity_project_v3.developer[each.value].id
  password          = var.default_user_password
  description       = "Developer"
}

# ──────────────────────────────────────────────
# 5. Group membership
#    openstack_identity_group_membership_v3 does not exist in the
#    current provider version — membership is defined per-user instead.
# ──────────────────────────────────────────────
resource "openstack_identity_user_membership_v3" "leads" {
  for_each = toset(var.leads)
  user_id  = openstack_identity_user_v3.lead[each.value].id
  group_id = openstack_identity_group_v3.leads.id
}

resource "openstack_identity_user_membership_v3" "developers" {
  for_each = toset(var.developers)
  user_id  = openstack_identity_user_v3.developer[each.value].id
  group_id = openstack_identity_group_v3.developers.id
}

# ──────────────────────────────────────────────
# 6. Data — built-in roles
# ──────────────────────────────────────────────
data "openstack_identity_role_v3" "admin" {
  name = "admin"
}

data "openstack_identity_role_v3" "member" {
  name = "member"
}

data "openstack_identity_role_v3" "reader" {
  name = "reader"
}

data "openstack_identity_role_v3" "swiftoperator" {
  name = "swiftoperator"
}

# ──────────────────────────────────────────────
# 7. Role assignments
# ──────────────────────────────────────────────

# Leads get admin on the shared project
resource "openstack_identity_role_assignment_v3" "leads_shared_admin" {
  group_id   = openstack_identity_group_v3.leads.id
  project_id = openstack_identity_project_v3.shared.id
  role_id    = data.openstack_identity_role_v3.admin.id
}

# Leads get reader on every developer project (visibility)
resource "openstack_identity_role_assignment_v3" "leads_dev_reader" {
  for_each   = toset(var.developers)
  group_id   = openstack_identity_group_v3.leads.id
  project_id = openstack_identity_project_v3.developer[each.value].id
  role_id    = data.openstack_identity_role_v3.reader.id
}

# Each developer gets member on their own project only
resource "openstack_identity_role_assignment_v3" "dev_own_member" {
  for_each   = toset(var.developers)
  user_id    = openstack_identity_user_v3.developer[each.value].id
  project_id = openstack_identity_project_v3.developer[each.value].id
  role_id    = data.openstack_identity_role_v3.member.id
}

# Each developer also gets swiftoperator on their own project, for real
# Swift API access to their own container (not just Horizon/member access)
resource "openstack_identity_role_assignment_v3" "dev_own_swiftoperator" {
  for_each   = toset(var.developers)
  user_id    = openstack_identity_user_v3.developer[each.value].id
  project_id = openstack_identity_project_v3.developer[each.value].id
  role_id    = data.openstack_identity_role_v3.swiftoperator.id
}
