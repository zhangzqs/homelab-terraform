output "heartbeat_received" {
  description = "Whether heartbeat was successfully received from agent"
  value       = true
  depends_on  = [terraform_data.heartbeat_wait]
}

output "result" {
  description = "Full result from heartbeat script"
  value = {
    status = "heartbeat confirmed"
    run_id = terraform_data.heartbeat_wait.id
  }
  depends_on = [terraform_data.heartbeat_wait]
}
