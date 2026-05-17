data "archive_file" "runtime_payload" {
  type        = "zip"
  output_path = "${path.root}/.terraform/runtime-payload.zip"

  source {
    content  = file("${path.module}/scripts/agent.py")
    filename = "agent.py"
  }

  source {
    content  = file("${path.module}/../shared/mqtt_crypto.py")
    filename = "mqtt_crypto.py"
  }

  source {
    content  = file("${path.module}/../shared/mqtt_light.py")
    filename = "mqtt_light.py"
  }
}

data "local_file" "runtime_payload_b64" {
  filename = data.archive_file.runtime_payload.output_path
}

locals {
  rendered = templatefile("${path.module}/templates/user-data.sh", {
    runtime_payload_tar_b64   = data.local_file.runtime_payload_b64.content_base64
    broker_host               = var.mqtt_config.broker_host
    broker_port               = var.mqtt_config.broker_port
    topic_prefix              = var.mqtt_config.topic_prefix
    instance_id               = var.crypto_bundle.node_id
    poll_interval             = var.poll_interval
    replay_window_seconds     = var.replay_window_seconds
    ledger_path               = var.ledger_path
    max_workers               = var.max_workers
    python_executable         = var.python_executable
    agent_certificate_pem     = var.crypto_bundle.agent_certificate_pem
    agent_private_key_pem     = var.crypto_bundle.agent_private_key_pem
    terraform_certificate_pem = var.crypto_bundle.terraform_certificate_pem
  })
}
