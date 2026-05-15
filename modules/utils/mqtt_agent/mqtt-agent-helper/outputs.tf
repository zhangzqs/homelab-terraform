output "crypto_bundle" {
  description = "Cryptographic bundle containing certificates and private keys"
  value = {
    node_id                   = random_uuid.node_id.result
    agent_certificate_pem     = tls_self_signed_cert.agent_side.cert_pem
    agent_private_key_pem     = tls_private_key.agent_side.private_key_pem
    terraform_certificate_pem = tls_self_signed_cert.terraform_side.cert_pem
    terraform_private_key_pem = tls_private_key.terraform_side.private_key_pem
  }
  sensitive = true
}

output "node_id" {
  description = "Unique node ID for MQTT topic"
  value       = random_uuid.node_id.result
}
