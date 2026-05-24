locals {
  proxy_providers_yaml      = length(var.proxy_providers) > 0 ? indent(2, yamlencode(var.proxy_providers)) : ""
  proxy_groups_yaml         = length(var.proxy_groups) > 0 ? indent(2, yamlencode(var.proxy_groups)) : ""
  extra_rule_providers_yaml = length(var.extra_rule_providers) > 0 ? indent(2, yamlencode(var.extra_rule_providers)) : ""
  extra_rules_before_yaml   = length(var.extra_rules_before) > 0 ? indent(2, yamlencode(var.extra_rules_before)) : ""
  extra_rules_after_yaml    = length(var.extra_rules_after) > 0 ? indent(2, yamlencode(var.extra_rules_after)) : ""
  listeners_yaml            = length(var.listeners) > 0 ? indent(2, yamlencode(var.listeners)) : ""

  config_content = templatefile("${path.module}/config.yaml.tpl", {
    proxy_providers_yaml      = local.proxy_providers_yaml
    proxy_groups_yaml         = local.proxy_groups_yaml
    extra_rule_providers_yaml = local.extra_rule_providers_yaml
    extra_rules_before_yaml   = local.extra_rules_before_yaml
    extra_rules_after_yaml    = local.extra_rules_after_yaml
    external_controller       = var.external_controller
    overseas_proxy_name       = var.overseas_proxy_name
    default_rule_target       = var.default_rule_target
    listeners_yaml            = local.listeners_yaml
  })

  config_parsed = yamldecode(local.config_content)
}

output "config_content" {
  description = "Mihomo 配置文件内容（已验证 YAML 格式）"
  value       = local.config_content
}
