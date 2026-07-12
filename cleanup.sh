#!/bin/bash
source /home/heat-admin/overcloudrc

echo "=== CLEANUP START ==="

# Delete all VMs with vm- prefix
echo "Deleting VMs..."
for vm in $(openstack server list --all-projects -f value -c Name 2>/dev/null | grep "^vm-"); do
    openstack server delete "$vm" --wait 2>/dev/null && echo "  Deleted VM: $vm"
done

# Delete all volumes with vol- prefix
echo "Deleting volumes..."
for vol in $(openstack volume list --all-projects -f value -c Name 2>/dev/null | grep "^vol-"); do
    openstack volume delete "$vol" 2>/dev/null && echo "  Deleted volume: $vol"
done

# Delete all custom security groups (not default, not lb-)
echo "Deleting security groups..."
for sg in $(openstack security group list -f value -c ID -c Name 2>/dev/null | grep -E "^.+ sg-" | awk '{print $1}'); do
    openstack security group delete "$sg" 2>/dev/null && echo "  Deleted SG: $sg"
done

# Delete subnets and networks with vnet- prefix
echo "Deleting networks..."
for net in $(openstack network list -f value -c Name 2>/dev/null | grep "^vnet-"); do
    for sub in $(openstack subnet list --network "$net" -f value -c ID 2>/dev/null); do
        openstack subnet delete "$sub" 2>/dev/null && echo "  Deleted subnet in $net"
    done
    openstack network delete "$net" 2>/dev/null && echo "  Deleted network: $net"
done

# Delete custom users
echo "Deleting users..."
for user in ana_anic luka_lukic marko_marinkovic; do
    openstack user delete "$user" 2>/dev/null && echo "  Deleted user: $user"
done

# Delete techsprint project
openstack project delete techsprint 2>/dev/null && echo "  Deleted project: techsprint"

echo "=== CLEANUP DONE ==="
