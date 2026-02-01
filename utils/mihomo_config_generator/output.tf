locals {
  # 生成配置内容
  config_content = templatefile("${path.module}/config.yaml.tpl", {
    working_dir     = var.working_dir,
    port            = var.mixed_port,
    proxy_providers = var.proxy_providers,
    custom_proxies  = var.custom_proxies,
  })

  # 验证 YAML 格式是否正确
  # 如果 YAML 格式有误，yamldecode 会抛出错误，Terraform 会提前失败
  config_parsed = yamldecode(local.config_content)
}

output "config_content" {
  description = "Mihomo配置文件内容（已验证 YAML 格式）"
  value       = local.config_content
}
