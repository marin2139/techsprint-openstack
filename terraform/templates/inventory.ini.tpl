[bastion]
vm-bastion ansible_host=${bastion_ip}

[lead]
%{ for name, ip in lead_ips ~}
vm-lead-${name} ansible_host=${ip}
%{ endfor ~}

[moodle]
%{ for name, ip in moodle_ips ~}
vm-moodle-${name} ansible_host=${ip}
%{ endfor ~}

[all:vars]
ansible_user=cloud-user
ansible_ssh_private_key_file=${ssh_key_path}
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyJump=cloud-user@${bastion_host}'

[bastion:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
