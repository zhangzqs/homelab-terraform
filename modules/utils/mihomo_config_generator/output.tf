locals {
  config = merge(local.static_config, local.dynamic_config)
}

output "config_content" {
  description = "Mihomo 配置文件内容"
  value       = yamlencode(local.config)
}
