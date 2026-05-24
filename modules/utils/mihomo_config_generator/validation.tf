resource "terraform_data" "validate_proxy_sources" {
  lifecycle {
    precondition {
      condition     = length(var.proxy_providers) > 0 || length(var.proxy_groups) > 0
      error_message = "必须至少配置 proxy_providers 或 proxy_groups 其中之一"
    }
  }
}

check "config_validation" {
  assert {
    condition     = contains(keys(local.config_parsed), "mode")
    error_message = "生成的配置缺少 'mode' 字段"
  }

  assert {
    condition     = contains(keys(local.config_parsed), "listeners")
    error_message = "生成的配置缺少 'listeners' 字段"
  }

  assert {
    condition     = contains(keys(local.config_parsed), "rules")
    error_message = "生成的配置缺少 'rules' 字段"
  }

  assert {
    condition     = contains(keys(local.config_parsed), "proxy-groups")
    error_message = "生成的配置缺少 'proxy-groups' 字段"
  }

  assert {
    condition     = try(length(local.config_parsed["proxy-groups"]), 0) > 0
    error_message = "至少需要一个代理组"
  }
}
