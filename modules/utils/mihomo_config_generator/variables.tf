variable "proxy_providers" {
  description = "代理提供者配置（完全自定义，对应 mihomo proxy-providers 字段）"
  type        = any
  default = {
    # 订阅地址示例（需替换为实际可用的订阅地址）：
    # provider1 = {
    #   type     = "http"
    #   url      = "https://example.com/path/to/your/subscription"
    #   interval = 3600
    #   path     = "./proxies/provider1.yaml"
    # }
  }
}

variable "proxy_groups" {
  description = "代理组配置（完全自定义，对应 mihomo proxy-groups 字段）"
  type        = any
  default     = []
}

variable "proxies" {
  description = "代理服务器配置（完全自定义，对应 mihomo proxies 字段）"
  type        = any
  default     = []
}

variable "extra_rule_providers" {
  description = "额外的规则集提供者，会追加到内置默认规则集之后（对应 mihomo rule-providers 字段）"
  type        = any
  default     = {}
}

variable "overseas_proxy_name" {
  description = "海外代理组名称，内置规则中需要走代理时引用此名称"
  type        = string

  validation {
    condition     = length(var.overseas_proxy_name) > 0
    error_message = "overseas_proxy_name 不能为空"
  }
}

variable "external_controller" {
  description = "RESTful API 监听地址"
  type        = string
  default     = "127.0.0.1:9093"
}

variable "default_rule_target" {
  description = "MATCH 兜底规则的目标（通常是代理组名称或 DIRECT/REJECT）"
  type        = string
  default     = "DIRECT"

  validation {
    condition     = length(var.default_rule_target) > 0
    error_message = "default_rule_target 不能为空"
  }
}

variable "extra_rules_before" {
  description = "追加在内置规则之前的额外规则列表"
  type        = any
  default     = []
}

variable "extra_rules_after" {
  description = "追加在内置规则之后的额外规则列表"
  type        = any
  default     = []
}

variable "listeners" {
  description = "监听器配置（完全自定义，对应 mihomo listeners 字段）"
  type        = any
  default     = []
}

variable "dns_config" {
  description = "DNS 配置扩展（会与默认配置 merge，对应 mihomo dns 字段）"
  type        = any
  default     = {}
}
