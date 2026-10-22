output "config_content" {
  description = "通过 Mihomo 内核校验的配置内容"
  # 使用 apply 后才确定的 output，避免校验失败时发布 plan 阶段已知的配置。
  value = (
    terraform_data.validation.output.config_sha256 == sha256(var.config_content)
    ? var.config_content
    : null
  )
}
