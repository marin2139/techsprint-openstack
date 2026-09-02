#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  TechSprint OpenStack — Full Deploy${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# ──────────────────────────────────────────────
# Step 1: Terraform
# ──────────────────────────────────────────────
echo -e "${YELLOW}[1/3] Running Terraform...${NC}"
cd "$PROJECT_DIR/terraform"

if [ ! -f terraform.tfvars ]; then
    echo -e "${RED}ERROR: terraform/terraform.tfvars not found.${NC}"
    echo -e "Copy terraform.tfvars.example to terraform.tfvars and fill in your values."
    exit 1
fi

terraform init -upgrade
terraform plan -out=tfplan
terraform apply tfplan

echo -e "${GREEN}✓ Infrastructure provisioned${NC}"
echo ""

# ──────────────────────────────────────────────
# Step 2: Generate Ansible inventory
# ──────────────────────────────────────────────
echo -e "${YELLOW}[2/3] Generating Ansible inventory...${NC}"
cd "$PROJECT_DIR/ansible"

terraform -chdir="$PROJECT_DIR/terraform" output -raw ansible_inventory > inventory.ini

echo -e "${GREEN}✓ Inventory generated${NC}"
cat inventory.ini
echo ""

# ──────────────────────────────────────────────
# Step 3: Run Ansible
# ──────────────────────────────────────────────
echo -e "${YELLOW}[3/3] Running Ansible playbook...${NC}"

# Wait for VMs to be reachable
echo "Waiting 30s for VMs to boot..."
sleep 30

ansible-playbook site.yml

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  DEPLOYMENT COMPLETE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Bastion IP:${NC} $(terraform -chdir="$PROJECT_DIR/terraform" output -raw bastion_floating_ip)"
echo -e "${YELLOW}SSH:${NC} ssh -i ssh_key cloud-user@\$(terraform -chdir="$PROJECT_DIR/terraform" output -raw bastion_floating_ip)"
