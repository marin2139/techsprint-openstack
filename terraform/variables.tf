# ──────────────────────────────────────────────
# Provider / Auth
# ──────────────────────────────────────────────
variable "openstack_auth_url" {
  description = "Keystone auth URL (v3)"
  type        = string
}

variable "openstack_region" {
  description = "OpenStack region"
  type        = string
  default     = "regionOne"
}

variable "admin_username" {
  description = "Admin username for provider auth"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Admin password for provider auth"
  type        = string
  sensitive   = true
}

variable "admin_project" {
  description = "Admin project (tenant) name"
  type        = string
  default     = "admin"
}

variable "admin_domain" {
  description = "Admin domain name"
  type        = string
  default     = "Default"
}

# ──────────────────────────────────────────────
# Project
# ──────────────────────────────────────────────
variable "project_name" {
  description = "Base project name"
  type        = string
  default     = "techsprint"
}

variable "environment" {
  description = "Environment tag (dev / staging / prod)"
  type        = string
  default     = "dev"
}

# ──────────────────────────────────────────────
# External network
# ──────────────────────────────────────────────
variable "external_network_id" {
  description = "UUID of the provider/external network for floating IPs and router gateway"
  type        = string
}

# ──────────────────────────────────────────────
# Image & Flavor
# ──────────────────────────────────────────────
variable "image_name" {
  description = "Glance image for all VMs (RHEL 8) — NOT octavia-amphora"
  type        = string
  default     = "rhel8"
}

variable "flavor_bastion" {
  description = "Flavor for bastion / lead VMs"
  type        = string
  default     = "default"
}

variable "flavor_moodle" {
  description = "Flavor for Moodle VMs (≥4 GB RAM as required) — custom flavor, must exist on the lab (openstack flavor create m1.moodle --ram 4096 --disk 20 --vcpus 2)"
  type        = string
  default     = "m1.moodle"
}

# ──────────────────────────────────────────────
# Users
# ──────────────────────────────────────────────
variable "developers" {
  description = "List of developer usernames (first_last)"
  type        = list(string)
  default     = ["luka_lukic", "marko_marinkovic"]
}

variable "leads" {
  description = "List of DevOps lead usernames (first_last)"
  type        = list(string)
  default     = ["ana_anic"]
}

variable "default_user_password" {
  description = "Default password for created users"
  type        = string
  sensitive   = true
  default     = "TechSprint2026!"
}

# ──────────────────────────────────────────────
# Networking
# ──────────────────────────────────────────────
variable "mgmt_cidr" {
  description = "CIDR for management network"
  type        = string
  default     = "10.0.0.0/24"
}

variable "admin_ip_cidr" {
  description = "Admin's own public IP (as /32) allowed direct SSH to the Lead VM from the internet. REPLACE with your actual public IP before applying."
  type        = string
  default     = "203.0.113.1/32"
}

variable "dev_cidr_prefix" {
  description = "First two octets for per-developer subnets (10.X.0.0/24)"
  type        = number
  default     = 100
}

# ──────────────────────────────────────────────
# Storage
# ──────────────────────────────────────────────
variable "cinder_volume_size" {
  description = "Data volume size in GB per Moodle instance"
  type        = number
  default     = 10
}

variable "manila_share_size" {
  description = "Manila shared filesystem size in GB"
  type        = number
  default     = 5
}

variable "manila_share_protocol" {
  description = "Manila share protocol (NFS or CIFS)"
  type        = string
  default     = "NFS"
}

# ──────────────────────────────────────────────
# SSH
# ──────────────────────────────────────────────
variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "../ssh_key.pub"
}
