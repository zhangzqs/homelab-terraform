mode: rule

geox-url:
  geoip: "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat"
  geosite: "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat"
  mmdb: "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.metadb"

geo-auto-update: true
geo-update-interval: 24

log-level: debug
ipv6: true

external-controller: ${external_controller}

external-ui: "./ui"
external-ui-name: xd
external-ui-url: "https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"

external-doh-server: /dns-query

%{ if proxy_providers_yaml != "" }
proxy-providers:
${proxy_providers_yaml}
%{ endif }

%{ if proxy_groups_yaml != "" }
proxy-groups:
${proxy_groups_yaml}
%{ endif }

rule-providers:
  apple-proxy:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/Apple-proxy.yaml"
    path: ./ruleset/Apple-proxy.yaml
    interval: 3600

  apple-direct:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/Apple-direct.yaml"
    path: ./ruleset/Apple-direct.yaml
    interval: 3600

  cn:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/CN.yaml"
    path: ./ruleset/CN.yaml
    interval: 3600

  ad-keyword:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/common-ad-keyword.yaml"
    path: ./ruleset/common-ad-keyword.yaml
    interval: 3600

  foreign:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/foreign.yaml"
    path: ./ruleset/foreign.yaml
    interval: 3600

  telegram:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/App/social/Telegram.yaml"
    path: ./ruleset/Telegram.yaml
    interval: 3600

  lan:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/LAN.yaml"
    path: ./ruleset/LAN.yaml
    interval: 3600
%{ if extra_rule_providers_yaml != "" }
${extra_rule_providers_yaml}
%{ endif }


rules:
%{ if extra_rules_before_yaml != "" }
  # 前置用户自定义规则
${extra_rules_before_yaml}
%{ endif }
  - DOMAIN-SUFFIX,bing.com,DIRECT
  - RULE-SET,apple-proxy,${overseas_proxy_name}
  - RULE-SET,apple-direct,DIRECT
  - RULE-SET,cn,DIRECT
  - RULE-SET,ad-keyword,REJECT
  - RULE-SET,foreign,${overseas_proxy_name}
  - RULE-SET,telegram,${overseas_proxy_name}
  - RULE-SET,lan,DIRECT
  - GEOIP,CN,DIRECT
%{ if extra_rules_after_yaml != "" }
  # 后置用户自定义规则
${extra_rules_after_yaml}
%{ endif }
  # 默认规则
  - MATCH,${default_rule_target}


%{ if listeners_yaml != "" }
listeners:
${listeners_yaml}
%{ endif }
