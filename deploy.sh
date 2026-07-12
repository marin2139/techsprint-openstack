#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CSV_FILE="${1}"
NETWORK_ID="4beb2534-efb5-44b7-b6e4-aa098b0c2f9e"
IMAGE_NAME="octavia-amphora-16.1-20200812.3.x86_64"
FLAVOR_BASTION="default"
FLAVOR_MOODLE="default-extra-disk"

if [ -z "$CSV_FILE" ]; then
    echo -e "${RED}Usage: $0 <path-to-csv-file>${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$CSV_FILE" != /* ]]; then
    CSV_FILE="$SCRIPT_DIR/$CSV_FILE"
fi

if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}CSV not found: $CSV_FILE${NC}"
    exit 1
fi

# Source OpenStack credentials
if [ -f /home/heat-admin/overcloudrc ]; then
    source /home/heat-admin/overcloudrc
elif [ -n "$OS_AUTH_URL" ]; then
    echo "Using existing OpenStack credentials"
else
    echo -e "${RED}No OpenStack credentials found${NC}"
    exit 1
fi

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  TechSprint OpenStack Deployment${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# ============================================================
# STEP 1: Parse CSV
# ============================================================
echo -e "${YELLOW}[1/7] Parsing CSV...${NC}"

declare -a DEVELOPERS
declare -a LEADS
declare -a ALL_USERS

while IFS=';' read -r fname lname role; do
    [[ "$fname" == "ime" ]] && continue
    fname=$(echo "$fname" | xargs)
    lname=$(echo "$lname" | xargs)
    role=$(echo "$role" | xargs)
    full_name="${fname}_${lname}"
    ALL_USERS+=("$full_name:$role")

    if [ "$role" == "devops_lead" ]; then
        LEADS+=("$full_name")
        echo -e "  ${GREEN}Lead:${NC} $full_name"
    elif [ "$role" == "developer" ]; then
        DEVELOPERS+=("$full_name")
        echo -e "  ${GREEN}Developer:${NC} $full_name"
    fi
done < "$CSV_FILE"

echo -e "${GREEN}✓ Parsed: ${#DEVELOPERS[@]} developers, ${#LEADS[@]} leads${NC}"
echo ""

# ============================================================
# STEP 2: Create Keystone projects and users
# ============================================================
echo -e "${YELLOW}[2/7] Creating Keystone projects and users...${NC}"

# Create main project
openstack project show techsprint > /dev/null 2>&1 || \
    openstack project create techsprint --description "TechSprint testing environment" 2>/dev/null && \
    echo -e "  ${GREEN}Project: techsprint${NC}" || echo -e "  ${YELLOW}Project techsprint already exists${NC}"

# Create users
for user_entry in "${ALL_USERS[@]}"; do
    username=$(echo "$user_entry" | cut -d: -f1)
    role=$(echo "$user_entry" | cut -d: -f2)

    openstack user show "$username" > /dev/null 2>&1 || \
        openstack user create "$username" --password "TechSprint2026!" --project techsprint 2>/dev/null && \
        echo -e "  ${GREEN}User: $username ($role)${NC}" || echo -e "  ${YELLOW}User $username exists${NC}"

    if [ "$role" == "devops_lead" ]; then
        openstack role add --user "$username" --project techsprint admin 2>/dev/null || true
    else
        openstack role add --user "$username" --project techsprint member 2>/dev/null || true
    fi
done

echo -e "${GREEN}✓ Keystone users and projects created${NC}"
echo ""

# ============================================================
# STEP 3: Create networks per developer
# ============================================================
echo -e "${YELLOW}[3/7] Creating networks...${NC}"

# Management network for bastion and lead
openstack network show vnet-mgmt > /dev/null 2>&1 || \
    openstack network create vnet-mgmt 2>/dev/null && \
    echo -e "  ${GREEN}Network: vnet-mgmt${NC}" || echo -e "  ${YELLOW}vnet-mgmt exists${NC}"

openstack subnet show subnet-mgmt > /dev/null 2>&1 || \
    openstack subnet create subnet-mgmt --network vnet-mgmt --subnet-range 10.0.0.0/24 --dns-nameserver 8.8.8.8 2>/dev/null && \
    echo -e "  ${GREEN}Subnet: subnet-mgmt (10.0.0.0/24)${NC}" || echo -e "  ${YELLOW}subnet-mgmt exists${NC}"

# Per-developer networks
counter=100
for dev in "${DEVELOPERS[@]}"; do
    net_name="vnet-${dev}"
    sub_name="subnet-${dev}"
    cidr="10.${counter}.0.0/24"

    openstack network show "$net_name" > /dev/null 2>&1 || \
        openstack network create "$net_name" 2>/dev/null && \
        echo -e "  ${GREEN}Network: $net_name${NC}" || echo -e "  ${YELLOW}$net_name exists${NC}"

    openstack subnet show "$sub_name" > /dev/null 2>&1 || \
        openstack subnet create "$sub_name" --network "$net_name" --subnet-range "$cidr" --dns-nameserver 8.8.8.8 2>/dev/null && \
        echo -e "  ${GREEN}Subnet: $sub_name ($cidr)${NC}" || echo -e "  ${YELLOW}$sub_name exists${NC}"

    counter=$((counter + 1))
done

echo -e "${GREEN}✓ Networks created${NC}"
echo ""

# ============================================================
# STEP 4: Create security groups
# ============================================================
echo -e "${YELLOW}[4/7] Creating security groups...${NC}"

# Bastion SG - SSH from anywhere
openstack security group show sg-bastion > /dev/null 2>&1 || {
    openstack security group create sg-bastion --description "Bastion - SSH only" 2>/dev/null && \
    openstack security group rule create sg-bastion --protocol tcp --dst-port 22 --remote-ip 0.0.0.0/0 2>/dev/null && \
    openstack security group rule create sg-bastion --protocol icmp 2>/dev/null && \
    echo -e "  ${GREEN}SG: sg-bastion (SSH + ICMP)${NC}"
} || echo -e "  ${YELLOW}sg-bastion exists or quota reached${NC}"

# Developer SG - SSH from bastion, HTTP/HTTPS
openstack security group show sg-developer > /dev/null 2>&1 || {
    openstack security group create sg-developer --description "Developer - HTTP/HTTPS/SSH" 2>/dev/null && \
    openstack security group rule create sg-developer --protocol tcp --dst-port 22 --remote-ip 10.0.0.0/8 2>/dev/null && \
    openstack security group rule create sg-developer --protocol tcp --dst-port 80 2>/dev/null && \
    openstack security group rule create sg-developer --protocol tcp --dst-port 443 2>/dev/null && \
    openstack security group rule create sg-developer --protocol icmp 2>/dev/null && \
    echo -e "  ${GREEN}SG: sg-developer (SSH from bastion + HTTP/HTTPS)${NC}"
} || echo -e "  ${YELLOW}sg-developer exists or quota reached${NC}"

# Lead SG - SSH from anywhere, full access
openstack security group show sg-lead > /dev/null 2>&1 || {
    openstack security group create sg-lead --description "Lead - full access" 2>/dev/null && \
    openstack security group rule create sg-lead --protocol tcp --dst-port 22 --remote-ip 0.0.0.0/0 2>/dev/null && \
    openstack security group rule create sg-lead --protocol tcp --dst-port 80 2>/dev/null && \
    openstack security group rule create sg-lead --protocol tcp --dst-port 443 2>/dev/null && \
    openstack security group rule create sg-lead --protocol icmp 2>/dev/null && \
    echo -e "  ${GREEN}SG: sg-lead (full access)${NC}"
} || echo -e "  ${YELLOW}sg-lead exists or quota reached${NC}"

echo -e "${GREEN}✓ Security groups created${NC}"
echo ""

# ============================================================
# STEP 5: Create VMs
# ============================================================
echo -e "${YELLOW}[5/7] Creating VMs...${NC}"

# Determine which SG to use (fallback to default if custom ones failed)
BASTION_SG="sg-bastion"
openstack security group show sg-bastion > /dev/null 2>&1 || BASTION_SG="default"
DEV_SG="sg-developer"
openstack security group show sg-developer > /dev/null 2>&1 || DEV_SG="default"
LEAD_SG="sg-lead"
openstack security group show sg-lead > /dev/null 2>&1 || LEAD_SG="default"

# Bastion VM
openstack server show vm-bastion > /dev/null 2>&1 || {
    openstack server create vm-bastion \
        --image "$IMAGE_NAME" \
        --flavor "$FLAVOR_BASTION" \
        --nic net-id="$NETWORK_ID" \
        --security-group "$BASTION_SG" \
        --wait 2>&1 && \
    echo -e "  ${GREEN}VM: vm-bastion (bastion/jump host)${NC}"
} || echo -e "  ${YELLOW}vm-bastion exists${NC}"

# Lead VMs
for lead in "${LEADS[@]}"; do
    vm_name="vm-lead-${lead}"
    openstack server show "$vm_name" > /dev/null 2>&1 || {
        openstack server create "$vm_name" \
            --image "$IMAGE_NAME" \
            --flavor "$FLAVOR_BASTION" \
            --nic net-id="$NETWORK_ID" \
            --security-group "$LEAD_SG" \
            --wait 2>&1 && \
        echo -e "  ${GREEN}VM: $vm_name (DevOps Lead)${NC}"
    } || echo -e "  ${YELLOW}$vm_name exists${NC}"
done

# Moodle VMs (2 per developer)
for dev in "${DEVELOPERS[@]}"; do
    for i in 1 2; do
        vm_name="vm-moodle-${dev}-${i}"
        openstack server show "$vm_name" > /dev/null 2>&1 || {
            openstack server create "$vm_name" \
                --image "$IMAGE_NAME" \
                --flavor "$FLAVOR_MOODLE" \
                --nic net-id="$NETWORK_ID" \
                --security-group "$DEV_SG" \
                --wait 2>&1 && \
            echo -e "  ${GREEN}VM: $vm_name (Moodle instance $i)${NC}"
        } || echo -e "  ${YELLOW}$vm_name exists${NC}"
    done
done

echo -e "${GREEN}✓ All VMs created${NC}"
echo ""

# ============================================================
# STEP 6: Create and attach Cinder volumes
# ============================================================
echo -e "${YELLOW}[6/7] Creating data volumes...${NC}"

for dev in "${DEVELOPERS[@]}"; do
    for i in 1 2; do
        vm_name="vm-moodle-${dev}-${i}"
        vol_name="vol-data-${dev}-${i}"

        openstack volume show "$vol_name" > /dev/null 2>&1 || {
            openstack volume create "$vol_name" --size 10 2>/dev/null && \
            echo -e "  ${GREEN}Volume: $vol_name (10GB)${NC}"
        } || echo -e "  ${YELLOW}$vol_name exists${NC}"

        # Wait for volume to be available
        sleep 2

        # Attach volume to VM
        openstack server add volume "$vm_name" "$vol_name" 2>/dev/null && \
            echo -e "  ${GREEN}Attached: $vol_name -> $vm_name${NC}" || \
            echo -e "  ${YELLOW}$vol_name already attached or error${NC}"
    done
done

echo -e "${GREEN}✓ Volumes created and attached${NC}"
echo ""

# ============================================================
# STEP 7: Summary
# ============================================================
echo -e "${YELLOW}[7/7] Deployment summary...${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  DEPLOYMENT COMPLETE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}Created VMs:${NC}"
openstack server list --project admin -f table 2>/dev/null | grep "vm-" || openstack server list -f table 2>/dev/null | grep "vm-"

echo ""
echo -e "${YELLOW}Created Networks:${NC}"
openstack network list -f table 2>/dev/null | grep "vnet-"

echo ""
echo -e "${YELLOW}Created Volumes:${NC}"
openstack volume list -f table 2>/dev/null | grep "vol-" || echo "  No volumes found"

echo ""
echo -e "${YELLOW}Created Users:${NC}"
for user_entry in "${ALL_USERS[@]}"; do
    username=$(echo "$user_entry" | cut -d: -f1)
    role=$(echo "$user_entry" | cut -d: -f2)
    echo -e "  $username ($role)"
done

echo ""
echo -e "${YELLOW}Security Groups:${NC}"
openstack security group list -f table 2>/dev/null | grep "sg-" || echo "  Using default SG"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Git: https://github.com/marin2139/techsprint-openstack${NC}"
echo -e "${GREEN}========================================${NC}"
