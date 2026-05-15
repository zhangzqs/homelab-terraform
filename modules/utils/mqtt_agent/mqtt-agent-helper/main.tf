# 生成稳定的节点 ID（用于 MQTT topic）
resource "random_uuid" "node_id" {}

# Terraform 侧私钥（用于对 agent 回传的结果解密）
resource "tls_private_key" "terraform_side" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "terraform_side" {
  private_key_pem       = tls_private_key.terraform_side.private_key_pem
  validity_period_hours = 24 * 365
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "client_auth",
    "server_auth",
  ]

  subject {
    common_name  = "mqtt-instance-terraform"
    organization = "terraform-module"
  }
}

# Agent 侧私钥（用于对命令解密）
resource "tls_private_key" "agent_side" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "agent_side" {
  private_key_pem       = tls_private_key.agent_side.private_key_pem
  validity_period_hours = 24 * 365
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "client_auth",
    "server_auth",
  ]

  subject {
    common_name  = "mqtt-instance-agent"
    organization = "terraform-module"
  }
}
