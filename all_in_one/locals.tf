// 这个 locals 主要用于存储 Proxmox VE 的一些公共配置
// 这里先写死，有可能后面会按需改成变量
locals {
  pve_username               = "root@pam"
  pve_node_name              = "pve"
  pve_default_network_bridge = "vmbr0"
  pve_default_ipv4_gateway   = "192.168.242.1"
}

// 这个 locals 主要用于分配所有vm和lxc的ID，避免冲突
// 命名规则：pve_vm_id_<资源类型vm|lxc>_<资源名称>
locals {
  pve_vm_id_lxc_mihomo_proxy   = 200
  pve_vm_id_lxc_code_server    = 201
  pve_vm_id_vm_k3s_master      = 202
  pve_vm_id_lxc_storage_server = 203
}

// 这个 locals 主要用于分配所有vm和lxc的IPv4地址，避免冲突
// 命名规则：pve_ipv4_address_<资源类型vm|lxc>_<资源名称>
locals {
  pve_ipv4_address_lxc_mihomo_proxy = "192.168.242.200"
  pve_ipv4_address_lxc_code_server  = "192.168.242.201"
  pve_ipv4_address_vm_k3s_master    = "192.168.242.202"
  pve_ipv4_address_lxc_nfs_server   = "192.168.242.203"
}
