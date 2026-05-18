data "local_file" "result_cache" {
  filename   = local.result_file
  depends_on = [terraform_data.exec_command]
}

locals {
  cached_result = try(jsondecode(data.local_file.result_cache.content), null)
  exec_result = local.cached_result != null ? local.cached_result : {
    task_uuid   = random_uuid.task_uuid.result
    exit_code   = "0"
    output      = ""
    executed_at = ""
  }
}

output "result" {
  description = "完整执行结果"
  value       = local.exec_result
  sensitive   = true
  depends_on  = [data.local_file.result_cache]
}

output "task_uuid" {
  description = "任务 UUID"
  value       = local.exec_result.task_uuid
  depends_on  = [data.local_file.result_cache]
}

output "exit_code" {
  description = "命令退出码"
  value       = tonumber(local.exec_result.exit_code)
  depends_on  = [data.local_file.result_cache]
}

output "output" {
  description = "命令输出"
  value       = local.exec_result.output
  depends_on  = [data.local_file.result_cache]
}

output "executed_at" {
  description = "命令执行时间"
  value       = local.exec_result.executed_at
  depends_on  = [data.local_file.result_cache]
}
