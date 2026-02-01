mode: rule

geox-url:
  geoip: "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.dat"
  geosite: "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat"
  mmdb: "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip.metadb"

geo-auto-update: true # 是否自动更新 geodata
geo-update-interval: 24 # 更新间隔，单位：小时

log-level: debug # 日志等级 silent/error/warning/info/debug
ipv6: true # 开启 IPv6 总开关，关闭阻断所有 IPv6 链接和屏蔽 DNS 请求 AAAA 记录

external-controller: 0.0.0.0:9093 # RESTful API 监听地址

external-ui: "${working_dir}/ui" # 外置网页文件目录
external-ui-name: xd
external-ui-url: "https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"

# 在RESTful API端口上开启DOH服务器
external-doh-server: /dns-query
%{ if length(proxy_providers) > 0 }

proxy-providers:
%{ for name, config in proxy_providers ~}
  ${name}:
    type: http
    url: "${config.url}"
    interval: ${config.interval}
    path: ${working_dir}/proxies/${name}.yaml
    health-check:
      enable: true
      interval: 600
      url: https://cp.cloudflare.com/generate_204
      expected-status: 204
%{ endfor ~}
%{ endif ~}
%{ if length(custom_proxies) > 0 }

proxies:
%{ for name, config in custom_proxies ~}
  - name: "${name}"
    type: ${config.type}
    server: ${config.server}
    port: ${config.port}
    password: ${config.password}
%{ endfor ~}
%{ endif }

proxy-groups:

# 所有的代理提供者都作为独立的代理组, 并动态选择延迟最低的节点
%{ if length(proxy_providers) > 0 ~}
%{ for name, config in proxy_providers ~}
  - name: ${name}-Auto
    type: url-test
    url: "https://cp.cloudflare.com/generate_204"
    interval: 300
    use: [${name}]
%{ endfor ~}
%{ endif ~}

# 所有的代理提供者都作为独立的代理组, 提供一个手工选择的选项
%{ if length(proxy_providers) > 0 ~}
%{ for name, config in proxy_providers ~}
  - name: ${name}-Manual
    type: select
    use: [${name}]
%{ endfor ~}
%{ endif ~}

# 自定义的所有代理作为另一个自动选择延迟最低的代理组
%{ if length(custom_proxies) > 0 ~}
  - name: CustomProxies-Auto
    type: url-test
    url: "https://cp.cloudflare.com/generate_204"
    interval: 300
    proxies: [%{ for idx, name in keys(custom_proxies) }${name}%{ if idx < length(custom_proxies) - 1 }, %{ endif }%{ endfor }]
%{ endif }

# 自定义的所有代理作为另一个可以手工选择的代理组
%{ if length(custom_proxies) > 0 ~}
  - name: CustomProxies-Manual
    type: select
    proxies: [%{ for idx, name in keys(custom_proxies) }${name}%{ if idx < length(custom_proxies) - 1 }, %{ endif }%{ endfor }]
%{ endif }

  # fallback 将按照 url 测试结果按照节点顺序选择
  - name: "Fallback-Auto"
    type: fallback
    proxies:
%{ if length(custom_proxies) > 0 ~}
      # 优先使用自己定义的代理
      - CustomProxies-Auto
      - CustomProxies-Manual
%{ endif }
%{ for name, config in proxy_providers ~}
      - ${name}-Auto
      - ${name}-Manual
%{ endfor ~}
    url: "https://cp.cloudflare.com/generate_204"
    interval: 300

# 海外流量代理组
  - name: Proxy
    type: select
    proxies:
      # 优先使用支持自动选择延迟最低的 fallback 代理组
      - Fallback-Auto
%{ if length(custom_proxies) > 0 ~}
      # 优先使用自己定义的代理
      - CustomProxies-Auto
      - CustomProxies-Manual
%{ endif }
%{ for name, config in proxy_providers ~}
      - ${name}-Auto
      - ${name}-Manual
%{ endfor ~}

rule-providers:
  apple-proxy:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/Apple-proxy.yaml"
    path: ${working_dir}/ruleset/Apple-proxy.yaml
    interval: 3600

  apple-direct:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/Apple-direct.yaml"
    path: ${working_dir}/ruleset/Apple-direct.yaml
    interval: 3600

  cn:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/CN.yaml"
    path: ${working_dir}/ruleset/CN.yaml
    interval: 3600

  ad-keyword:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/common-ad-keyword.yaml"
    path: ${working_dir}/ruleset/common-ad-keyword.yaml
    interval: 3600

  foreign:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/foreign.yaml"
    path: ${working_dir}/ruleset/foreign.yaml
    interval: 3600

  telegram:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/App/social/Telegram.yaml"
    path: ${working_dir}/ruleset/Telegram.yaml
    interval: 3600

  lan:
    type: http
    behavior: classical
    url: "https://cdn.jsdelivr.net/gh/Hackl0us/SS-Rule-Snippet@master/Rulesets/Clash/Basic/LAN.yaml"
    path: ${working_dir}/ruleset/LAN.yaml
    interval: 3600

rules:
  - DOMAIN-SUFFIX,bing.com,DIRECT # 必应直连
  - RULE-SET,apple-proxy,Proxy # 走代理的 Apple
  - RULE-SET,apple-direct,DIRECT # 直连的 Apple
  - RULE-SET,cn,DIRECT # 中国网站直连
  - RULE-SET,ad-keyword,REJECT # 广告关键字屏蔽
  - RULE-SET,foreign,Proxy # 国外网站走代理
  - RULE-SET,telegram,Proxy # Telegram 走代理
  - RULE-SET,lan,DIRECT # 局域网直连
  - GEOIP,CN,DIRECT # 中国 IP 直连
  - MATCH,Proxy

listeners:
  - name: default-mixed-in
    type: mixed
    port: ${port}
    listen: 0.0.0.0
    rule: rules # 默认使用全局定义的rules规则集
