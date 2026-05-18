terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

resource "random_uuid" "task_uuid" {
  keepers = {
    command      = var.command
    command_type = var.command_type
    node_id      = var.crypto_bundle.node_id
  }
}

locals {
  exec_query = {
    broker_host               = var.mqtt_config.broker_host
    broker_port               = tostring(var.mqtt_config.broker_port)
    topic_prefix              = var.mqtt_config.topic_prefix
    instance_id               = var.crypto_bundle.node_id
    task_uuid                 = random_uuid.task_uuid.result
    command_type              = var.command_type
    command                   = var.command
    timeout                   = tostring(var.timeout)
    poll_interval             = tostring(var.poll_interval)
    terraform_private_key_pem = var.crypto_bundle.terraform_private_key_pem
    terraform_certificate_pem = var.crypto_bundle.terraform_certificate_pem
    agent_certificate_pem     = var.crypto_bundle.agent_certificate_pem
  }

  result_file = "${path.cwd}/.mqtt__agent_exec_result_cache/${random_uuid.task_uuid.result}.json"
}

resource "terraform_data" "exec_command" {
  triggers_replace = {
    command      = var.command
    command_type = var.command_type
    node_id      = var.crypto_bundle.node_id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      EXEC_QUERY       = jsonencode(local.exec_query)
      EXEC_RESULT_FILE = local.result_file
    }
    command = <<-EOT
      set -euo pipefail
      mkdir -p "$(dirname "$EXEC_RESULT_FILE")"
      printf '%s' "$EXEC_QUERY" | /usr/bin/python3 "${path.module}/scripts/exec.py" > "$EXEC_RESULT_FILE"
    EOT
  }
}
