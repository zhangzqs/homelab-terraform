resource "random_password" "container_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "tls_private_key" "container_key" {
  algorithm = "ED25519"
}

resource "terraform_data" "container_replacer" {
  triggers_replace = 1
}

resource "proxmox_virtual_environment_container" "immich_container" {
  lifecycle {
    replace_triggered_by = [terraform_data.container_replacer]
  }

  tags          = ["terraform"]
  description   = "Immich Photo Service"
  node_name     = var.pve_node_name
  vm_id         = var.vm_id
  started       = true
  start_on_boot = true
  unprivileged  = true

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = "${var.ipv4_address}/${var.ipv4_address_cidr}"
        gateway = var.ipv4_gateway
      }
    }

    user_account {
      keys = [
        trimspace(tls_private_key.container_key.public_key_openssh)
      ]
      password = random_password.container_password.result
    }
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_interface_bridge
  }

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_dedicated
    swap      = 0
  }

  disk {
    datastore_id = "local-lvm"
    size         = var.disk_size
  }

  features {
    nesting = true
  }

  operating_system {
    type             = "ubuntu"
    template_file_id = var.ubuntu_template_file_id
  }
}
