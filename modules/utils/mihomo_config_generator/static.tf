locals {
  static_config = {
    "mode" = "rule"

    "geox-url" = {
      "geoip"   = "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat"
      "geosite" = "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat"
      "mmdb"    = "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.metadb"
    }

    "geo-auto-update"     = true
    "geo-update-interval" = 24

    "log-level" = "debug"
    "ipv6"      = true

    "external-controller" = var.external_controller

    "external-ui"      = "./ui"
    "external-ui-name" = "xd"
    "external-ui-url"  = "https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"

    "external-doh-server" = "/dns-query"
  }

  default_rule_providers = {
    "apple-proxy" = {
      type     = "http"
      behavior = "classical"
      url      = "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/Apple-proxy.yaml"
      path     = "./ruleset/Apple-proxy.yaml"
      interval = 3600
    }
    "apple-direct" = {
      type     = "http"
      behavior = "classical"
      url      = "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/Apple-direct.yaml"
      path     = "./ruleset/Apple-direct.yaml"
      interval = 3600
    }
    "cn" = {
      type     = "http"
      behavior = "classical"
      url      = "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/CN.yaml"
      path     = "./ruleset/CN.yaml"
      interval = 3600
    }
    "ad-keyword" = {
      type     = "http"
      behavior = "classical"
      url      = "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/common-ad-keyword.yaml"
      path     = "./ruleset/common-ad-keyword.yaml"
      interval = 3600
    }
    foreign = {
      type     = "http"
      behavior = "classical"
      url      = "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/foreign.yaml"
      path     = "./ruleset/foreign.yaml"
      interval = 3600
    }
    telegram = {
      type     = "http"
      behavior = "classical"
      url      = "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/App/social/Telegram.yaml"
      path     = "./ruleset/Telegram.yaml"
      interval = 3600
    }
    lan = {
      type     = "http"
      behavior = "classical"
      url      = "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/LAN.yaml"
      path     = "./ruleset/LAN.yaml"
      interval = 3600
    }
  }
  default_rules = [
    "DOMAIN-SUFFIX,bing.com,DIRECT",
    "RULE-SET,apple-proxy,${var.overseas_proxy_name}",
    "RULE-SET,apple-direct,DIRECT",
    "RULE-SET,cn,DIRECT",
    "RULE-SET,ad-keyword,REJECT",
    "RULE-SET,foreign,${var.overseas_proxy_name}",
    "RULE-SET,telegram,${var.overseas_proxy_name}",
    "RULE-SET,lan,DIRECT",
    "GEOIP,CN,DIRECT",
  ]
}
