resource "random_password" "container_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_password" "db_password" {
  length  = 24
  special = false
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

locals {
  docker_compose_content = templatefile("${path.module}/templates/docker-compose.yml.tpl", {
    immich_port = var.immich_port
  })
  immich_env_content = templatefile("${path.module}/templates/immich.env.tpl", {
    upload_location  = var.upload_location
    db_data_location = var.db_data_location
    timezone         = var.timezone
    immich_version   = var.immich_version
    db_password      = random_password.db_password.result
  })
  configure_docker_proxy_script = join("\n", var.install_proxy != null ? [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    "mkdir -p /etc/systemd/system/docker.service.d",
    "cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<'EOF'",
    "[Service]",
    "Environment=\"HTTP_PROXY=${var.install_proxy.http_proxy}\"",
    "Environment=\"HTTPS_PROXY=${var.install_proxy.https_proxy}\"",
    "EOF",
    "systemctl daemon-reload",
    "systemctl restart docker",
    ] : [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    "rm -f /etc/systemd/system/docker.service.d/http-proxy.conf",
    "systemctl daemon-reload",
    "systemctl restart docker",
  ])
}

resource "null_resource" "setup_container" {
  depends_on = [
    proxmox_virtual_environment_container.immich_container
  ]

  triggers = {
    res_vm_id   = proxmox_virtual_environment_container.immich_container.id
    version     = 1
    file_hash   = filesha256("${path.module}/scripts/setup.sh")
    host        = var.ipv4_address
    working_dir = var.working_dir
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = var.ipv4_address
    private_key = tls_private_key.container_key.private_key_pem
    timeout     = "5m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup.sh"
    destination = "/tmp/setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup.sh",
      "/tmp/setup.sh",
      "rm -f /tmp/setup.sh",
    ]
  }
}

resource "null_resource" "deploy_immich" {
  depends_on = [
    null_resource.configure_docker_proxy
  ]

  triggers = {
    res_vm_id           = proxmox_virtual_environment_container.immich_container.id
    docker_compose_hash = sha256(local.docker_compose_content)
    immich_env_hash     = sha256(local.immich_env_content)
    working_dir         = var.working_dir
    upload_location     = var.upload_location
    db_data_location    = var.db_data_location
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = var.ipv4_address
    private_key = tls_private_key.container_key.private_key_pem
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${var.working_dir}",
      "mkdir -p ${var.upload_location}",
      "mkdir -p ${var.db_data_location}",
    ]
  }

  provisioner "file" {
    content     = local.immich_env_content
    destination = "${var.working_dir}/.env"
  }

  provisioner "file" {
    content     = local.docker_compose_content
    destination = "${var.working_dir}/docker-compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "cd ${var.working_dir} && docker compose up -d",
      "cd ${var.working_dir} && docker compose ps",
    ]
  }
}

resource "null_resource" "configure_docker_proxy" {
  depends_on = [
    null_resource.setup_container
  ]

  triggers = {
    res_vm_id         = proxmox_virtual_environment_container.immich_container.id
    docker_proxy_hash = sha256(local.configure_docker_proxy_script)
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = var.ipv4_address
    private_key = tls_private_key.container_key.private_key_pem
    timeout     = "5m"
  }

  provisioner "file" {
    content     = local.configure_docker_proxy_script
    destination = "/tmp/configure-docker-proxy.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/configure-docker-proxy.sh",
      "/tmp/configure-docker-proxy.sh",
      "rm -f /tmp/configure-docker-proxy.sh",
    ]
  }
}
