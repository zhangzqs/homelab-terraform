locals {
  default_dns_config = merge(
    { # 基础配置
      enable = true
      listen = "0.0.0.0:53"

      # 是否基于quic解析
      prefer-h3 : false

      # DNS 解析也要遵循路由策略
      respect-rules : true

      # 是否启用系统Hosts文件解析
      use-system-hosts : false

      # IPv6代理支持
      ipv6 : true
    },
    { # DNS 配置

      # 全局兜底的DNS配置，当主 DNS 解析超时、失败、污染时，自动切换到这一组兜底，从上到下依次尝试
      default-nameserver = [
        "system",               # 优先调用 系统原生DNS（网卡配置的DNS）
        "223.6.6.6",            # 阿里公共DNS IPv4
        "8.8.8.8",              # 谷歌公共DNS IPv4
        "2400:3200::1",         # 阿里 IPv6 DNS
        "2001:4860:4860::8888", # 谷歌 IPv6 DNS
      ]
      # 绝大多数域名的默认解析服务器（直连流量默认走这里）。
      nameserver = [
        "8.8.8.8",                          # 传统UDP DNS（谷歌）
        "https://doh.pub/dns-query",        # DoH 加密DNS（国内公共纯净DoH）
        "https://dns.alidns.com/dns-query", # 阿里 DoH 加密DNS
      ]

      # 直连流量专属 DNS（被规则判定为直连的域名，优先用这组）
      direct-nameserver-follow-policy : false
      direct-nameserver : []

      # 被路由规则判定为 走代理（Proxy / 代理组） 的域名，强制使用这组 DNS 解析，不再走全局 nameserver。
      proxy-server-nameserver = [
        "https://doh.pub/dns-query",
        "https://dns.alidns.com/dns-query",
        "tls://223.5.5.5",
      ]
    },
    {
      # fake-ip 相关配置，黑名单模式，一些网站不参与fake-ip的解析
      enhanced-mode = "fake-ip"
      fake-ip-filter = [
        "*.lan",
        "*.local",
        "*.arpa",
        "time.*.com",
        "ntp.*.com",
        "time.*.com",
        "+.market.xiaomi.com",
        "localhost.ptlogin2.qq.com",
        "*.msftncsi.com",
        "www.msftconnecttest.com",
      ]
      fake-ip-filter-mode : "blacklist"
      fake-ip-range : "198.18.0.1/16"
    },
  )

  static_config = {
    "mode" = "rule"

    "dns" = merge(local.default_dns_config, var.dns_config)

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
