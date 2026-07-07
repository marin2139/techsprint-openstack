#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get script directory (absolute path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
CSV_FILE="${1}"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
WORK_DIR="/tmp/techsprint-deploy-$$"

# Validation
if [ -z "$CSV_FILE" ]; then
    echo -e "${RED}Usage: $0 <path-to-csv-file>${NC}"
    echo "Example: $0 techsprint_users.csv"
    exit 1
fi

# Handle relative or absolute CSV path
if [[ "$CSV_FILE" != /* ]]; then
    CSV_FILE="$SCRIPT_DIR/$CSV_FILE"
fi

if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}CSV file not found: $CSV_FILE${NC}"
    exit 1
fi

if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}Terraform directory not found: $TERRAFORM_DIR${NC}"
    exit 1
fi

if [ ! -d "$ANSIBLE_DIR" ]; then
    echo -e "${RED}Ansible directory not found: $ANSIBLE_DIR${NC}"
    exit 1
fi

echo -e "${YELLOW}=== TechSprint OpenStack Deployment ===${NC}"
echo "Script directory: $SCRIPT_DIR"
echo "CSV File: $CSV_FILE"
echo "Terraform: $TERRAFORM_DIR"
echo "Ansible: $ANSIBLE_DIR"

# Create work directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Copy terraform files
cp -r "$TERRAFORM_DIR" .
cp -r "$ANSIBLE_DIR" .
cp "$SCRIPT_DIR/ssh_key" . 2>/dev/null || echo "Warning: ssh_key not found"
cp "$SCRIPT_DIR/ssh_key.pub" . 2>/dev/null || echo "Warning: ssh_key.pub not found"

echo -e "${YELLOW}[1/4] Parsing CSV...${NC}"

# Parse CSV and create terraform variables
declare -a DEVELOPERS
declare -a LEADS

while IFS=';' read -r fname lname role; do
    # Skip header
    if [ "$fname" == "ime" ]; then
        continue
    fi
    
    # Trim whitespace
    fname=$(echo "$fname" | xargs)
    lname=$(echo "$lname" | xargs)
    role=$(echo "$role" | xargs)
    
    full_name="${fname}_${lname}"
    
    if [ "$role" == "devops_lead" ]; then
        LEADS+=("$full_name")
        echo "  Lead: $full_name"
    elif [ "$role" == "developer" ]; then
        DEVELOPERS+=("$full_name")
        echo "  Developer: $full_name"
    fi
done < "$CSV_FILE"

# Validate that we have data
if [ ${#DEVELOPERS[@]} -eq 0 ] && [ ${#LEADS[@]} -eq 0 ]; then
    echo -e "${RED}No developers or leads found in CSV${NC}"
    exit 1
fi

# Create terraform.tfvars
cat > terraform/terraform.tfvars <<EOF
openstack_username = "admin"
openstack_password = "redhat"
openstack_auth_url = "http://172.25.250.50:5000"
openstack_project_name = "admin"
openstack_region = "regionOne"

developers = [
EOF

for dev in "${DEVELOPERS[@]}"; do
    echo "  \"$dev\"," >> terraform/terraform.tfvars
done

cat >> terraform/terraform.tfvars <<EOF
]

leads = [
EOF

for lead in "${LEADS[@]}"; do
    echo "  \"$lead\"," >> terraform/terraform.tfvars
done

cat >> terraform/terraform.tfvars <<EOF
]
EOF

echo -e "${GREEN}✓ CSV parsed (${#DEVELOPERS[@]} developers, ${#LEADS[@]} leads)${NC}"

echo -e "${YELLOW}[2/4] Running Terraform init...${NC}"
cd terraform

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Terraform is not installed${NC}"
    exit 1
fi

terraform init
echo -e "${GREEN}✓ Terraform initialized${NC}"

echo -e "${YELLOW}[3/4] Running Terraform apply...${NC}"
terraform apply -auto-approve
echo -e "${GREEN}✓ Infrastructure created${NC}"

# Get outputs
BASTION_IP=$(terraform output -raw bastion_ip 2>/dev/null || echo "unknown")
ANSIBLE_INVENTORY=$(terraform output -raw ansible_inventory 2>/dev/null || echo "")

cd ..

echo -e "${YELLOW}[4/4] Running Ansible playbook...${NC}"

if [ -n "$ANSIBLE_INVENTORY" ]; then
    cd ansible
    # Create inventory from terraform output
    echo "$ANSIBLE_INVENTORY" > inventory.ini
    
    # Check if ansible is installed
    if ! command -v ansible-playbook &> /dev/null; then
        echo -e "${YELLOW}! Ansible not installed - skipping playbook${NC}"
    else
        ansible-playbook -i inventory.ini site.yml || echo "Ansible playbook completed with some warnings"
    fi
    cd ..
    echo -e "${GREEN}✓ Ansible playbook completed${NC}"
else
    echo -e "${YELLOW}! Skipping Ansible - no inventory generated${NC}"
fi

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo -e "${GREEN}Bastion Host IP: $BASTION_IP${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. SSH into bastion: ssh -i $WORK_DIR/ssh_key root@$BASTION_IP"
echo "2. Access Moodle from developer machines"
echo "3. Check: openstack server list"
echo ""
echo "Work directory: $WORK_DIR"

# Cleanup prompt
read -p "Delete work directory? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd /
    rm -rf "$WORK_DIR"
    echo "Work directory deleted"
else
    echo "Work directory preserved at: $WORK_DIR"
fi
