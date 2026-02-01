# 验证至少配置了一个代理源
resource "null_resource" "validate_proxy_sources" {
  lifecycle {
    precondition {
      condition     = length(var.proxy_providers) > 0 || length(var.custom_proxies) > 0
      error_message = "必须至少配置一个代理源（proxy_providers 或 custom_proxies）"
    }
  }
}

# 验证生成的配置包含必要的字段
locals {
  # 检查解析后的配置是否包含必要的字段
  has_mode           = contains(keys(local.config_parsed), "mode")
  has_listeners      = contains(keys(local.config_parsed), "listeners")
  has_rules          = contains(keys(local.config_parsed), "rules")
  has_proxy_groups   = contains(keys(local.config_parsed), "proxy-groups")

  # 检查是否有代理组
  proxy_groups_count = try(length(local.config_parsed["proxy-groups"]), 0)

  # 检查是否有 Proxy 主组
  has_main_proxy_group = try(
    anytrue([for g in local.config_parsed["proxy-groups"] : g.name == "Proxy"]),
    false
  )

  validation_results = {
    has_mode             = local.has_mode
    has_listeners        = local.has_listeners
    has_rules            = local.has_rules
    has_proxy_groups     = local.has_proxy_groups
    proxy_groups_count   = local.proxy_groups_count
    has_main_proxy_group = local.has_main_proxy_group
  }
}

# 如果配置验证失败，这里会报错
check "config_validation" {
  assert {
    condition     = local.has_mode
    error_message = "生成的配置缺少 'mode' 字段"
  }

  assert {
    condition     = local.has_listeners
    error_message = "生成的配置缺少 'listeners' 字段"
  }

  assert {
    condition     = local.has_rules
    error_message = "生成的配置缺少 'rules' 字段"
  }

  assert {
    condition     = local.has_proxy_groups
    error_message = "生成的配置缺少 'proxy-groups' 字段"
  }

  assert {
    condition     = local.proxy_groups_count > 0
    error_message = "至少需要一个代理组"
  }

  assert {
    condition     = local.has_main_proxy_group
    error_message = "必须包含名为 'Proxy' 的主代理组"
  }
}

# 输出验证结果（用于调试）
output "validation_results" {
  description = "配置验证结果"
  value       = local.validation_results
}
