output "config_content" {
  description = "Mihomo 配置文件内容"
  value       = yamlencode(merge(local.static_config, local.dynamic_config))
}
