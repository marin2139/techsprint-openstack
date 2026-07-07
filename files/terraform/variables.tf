variable "openstack_username" {
  description = "OpenStack username"
  type        = string
  sensitive   = true
}

variable "openstack_password" {
  description = "OpenStack password"
  type        = string
  sensitive   = true
}

variable "openstack_auth_url" {
  description = "OpenStack auth URL"
  type        = string
}

variable "openstack_project_name" {
  description = "OpenStack project name"
  type        = string
}

variable "openstack_region" {
  description = "OpenStack region"
  type        = string
}

variable "developers" {
  description = "List of developer names"
  type        = list(string)
  default     = []
}

variable "leads" {
  description = "List of DevOps lead names"
  type        = list(string)
  default     = []
}
