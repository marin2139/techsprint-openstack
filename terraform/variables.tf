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
  description = "Glance image for all VMs (CentOS 8 / RHEL 8)"
  type        = string
  default     = "centos8-stream"
}

variable "flavor_bastion" {
  description = "Flavor for bastion / lead VMs (≥2 GB RAM)"
  type        = string
  default     = "m1.small"
}

variable "flavor_moodle" {
  description = "Flavor for Moodle VMs (≥4 GB RAM as required)"
  type        = string
  default     = "m1.medium"
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
