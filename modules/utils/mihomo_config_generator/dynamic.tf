locals {
  dynamic_config = {
    "proxy-providers" = var.proxy_providers
    "proxy-groups"    = var.proxy_groups
    "proxies"         = var.proxies
    "rule-providers" = merge(
      local.default_rule_providers,
      var.extra_rule_providers,
    )
    "rules" = concat(
      var.extra_rules_before,
      local.default_rules,
      var.extra_rules_after,
      ["MATCH,${var.default_rule_target}"]
    )
    "listeners" = var.listeners
  }
}
