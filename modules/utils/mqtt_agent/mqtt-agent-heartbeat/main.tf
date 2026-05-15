locals {
  heartbeat_query = {
    broker_host               = var.mqtt_config.broker_host
    broker_port               = tostring(var.mqtt_config.broker_port)
    topic_prefix              = var.mqtt_config.topic_prefix
    instance_id               = var.crypto_bundle.node_id
    timeout                   = tostring(var.timeout)
    poll_interval             = tostring(var.poll_interval)
    terraform_private_key_pem = var.crypto_bundle.terraform_private_key_pem
    terraform_certificate_pem = var.crypto_bundle.terraform_certificate_pem
    agent_certificate_pem     = var.crypto_bundle.agent_certificate_pem
  }
}

resource "terraform_data" "heartbeat_wait" {
  triggers_replace = {
    compute_instance_id  = var.instance_id
    node_id              = var.crypto_bundle.node_id
    broker_host          = var.mqtt_config.broker_host
    broker_port          = tostring(var.mqtt_config.broker_port)
    topic_prefix         = var.mqtt_config.topic_prefix
    timeout              = tostring(var.timeout)
    poll_interval        = tostring(var.poll_interval)
    script_sha256        = filebase64sha256("${path.module}/scripts/heartbeat.py")
    terraform_cert_sha   = nonsensitive(sha256(var.crypto_bundle.terraform_certificate_pem))
    agent_cert_sha       = nonsensitive(sha256(var.crypto_bundle.agent_certificate_pem))
    terraform_key_sha256 = nonsensitive(sha256(var.crypto_bundle.terraform_private_key_pem))
  }

  provisioner "local-exec" {
    environment = {
      HEARTBEAT_QUERY = jsonencode(local.heartbeat_query)
    }
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      printf '%s' "$HEARTBEAT_QUERY" | /usr/bin/python3 "${path.module}/scripts/heartbeat.py"
    EOT
  }
}
