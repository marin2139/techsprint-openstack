# TechSprint — OpenStack Deployment

Multi-tenant Moodle hosting environment on Red Hat OpenStack Platform (RHOSP 16.1).

## Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │              External Network               │
                    └───────────┬─────────────┬───────────────────┘
                           Floating IP   Floating IP
                                │             │
                    ┌───────────┴─────────────┴───────────────────┐
                    │         vnet-mgmt (10.0.0.0/24)             │
                    │  ┌──────────┐  ┌──────────────────────┐     │
                    │  │ Bastion  │  │ Lead (ana_anic)       │     │
                    │  │ sg-bast. │  │ sg-lead, multi-NIC    │     │
                    │  └──────────┘  └──────────────────────┘     │
                    └─────────────────────────────────────────────┘
                                         │ Router
              ┌──────────────────────────┼──────────────────────────┐
              │                          │                          │
  ┌───────────┴───────────┐  ┌───────────┴───────────┐             │
  │ vnet-luka_lukic       │  │ vnet-marko_marinkovic  │           ...
  │ 10.100.0.0/24         │  │ 10.101.0.0/24          │
  │                       │  │                        │
  │ ┌─── Octavia LB ───┐ │  │ ┌─── Octavia LB ───┐  │
  │ │  lb-moodle-luka   │ │  │ │  lb-moodle-marko  │  │
  │ └───┬──────────┬────┘ │  │ └───┬──────────┬────┘  │
  │     │          │      │  │     │          │       │
  │ ┌───┴───┐ ┌───┴───┐  │  │ ┌───┴───┐ ┌───┴───┐   │
  │ │Moodle │ │Moodle │  │  │ │Moodle │ │Moodle │   │
  │ │  -1   │ │  -2   │  │  │ │  -1   │ │  -2   │   │
  │ │+Cinder│ │+Cinder│  │  │ │+Cinder│ │+Cinder│   │
  │ └───────┘ └───────┘  │  │ └───────┘ └───────┘   │
  └───────────────────────┘  └────────────────────────┘
```

## Components

| Component         | Technology                          | Purpose                              |
|-------------------|-------------------------------------|--------------------------------------|
| IaC               | Terraform (OpenStack provider)      | All infrastructure as code           |
| Configuration     | Ansible (roles-based)               | VM provisioning and app deployment   |
| Identity          | Keystone projects, groups, roles    | Tenant isolation + RBAC              |
| Networking        | Neutron per-developer networks      | Network isolation between tenants    |
| Load Balancing    | Octavia LB per developer            | HA across Moodle instance pair       |
| Block Storage     | Cinder volumes                      | Persistent data disks for Moodle     |
| Object Storage    | Swift containers                    | Backups + uploaded assets            |
| File Storage      | Manila (optional, see storage.tf)   | Shared moodledata for HA pair        |
| Compute           | Nova instances                      | Bastion, Lead, Moodle VMs            |

## Prerequisites

- RHOSP 16.1 access with admin credentials
- Terraform ≥ 1.3
- Ansible ≥ 2.9
- A CentOS 8 Stream or RHEL 8 Glance image
- A flavor with ≥ 4 GB RAM for Moodle VMs

## Quick Start

```bash
# 1. Configure
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your RHOSP values

# 2. Deploy everything
cd ../scripts/
chmod +x deploy.sh
./deploy.sh

# 3. Verify
ssh -i ssh_key cloud-user@<bastion-floating-ip>
```

## Manual Steps

```bash
# Terraform only
cd terraform/
terraform init
terraform plan
terraform apply

# Generate Ansible inventory from Terraform outputs
terraform output -raw ansible_inventory > ../ansible/inventory.ini

# Ansible only
cd ../ansible/
ansible-playbook site.yml
```

## Cleanup

```bash
./scripts/cleanup.sh
# or: cd terraform/ && terraform destroy
```

## File Structure

```
├── terraform/
│   ├── main.tf              # Provider, locals
│   ├── variables.tf         # All variables
│   ├── identity.tf          # Keystone: projects, groups, users, roles
│   ├── networking.tf        # Networks, subnets, router, SGs, floating IPs
│   ├── compute.tf           # Bastion, Lead, Moodle VMs
│   ├── storage.tf           # Cinder volumes, Swift containers, Manila
│   ├── loadbalancer.tf      # Octavia LB per developer
│   ├── outputs.tf           # IPs, inventory generation
│   └── terraform.tfvars.example
├── ansible/
│   ├── ansible.cfg
│   ├── site.yml
│   └── roles/
│       ├── common/          # Base packages, firewall
│       ├── bastion/         # Jump host config
│       ├── lead/            # Admin tools, SSH to all VMs
│       └── moodle/          # PHP, Apache, MariaDB, Moodle, volume mount
├── scripts/
│   ├── deploy.sh            # Full deploy (TF + Ansible)
│   └── cleanup.sh           # Destroy all
├── ssh_key / ssh_key.pub
├── techsprint_users.csv
└── README.md
```
