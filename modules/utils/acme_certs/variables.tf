
# acme.sh配置变量
variable "acme_sh_email" {
  description = "acme.sh注册使用的邮箱地址"
  type        = string
}

# acme.sh供应商
variable "acme_sh_dns_provider" {
  description = "acme.sh使用的DNS API供应商名称，例如：dns_cf、dns_aws等"
  type        = string
}

# acme.sh供应商配置参数，格式为JSON字符串，不同供应商需要的参数不同
variable "acme_sh_dns_provider_config" {
  description = "acme.sh使用的DNS API供应商配置参数，格式为JSON字符串，例如：{\"CF_Key\":\"your_cloudflare_api_key\",\"CF_Email\":\"your_email\"}"
  type        = map(string)
  sensitive   = true
}

# 家庭网络DNS泛域名
variable "home_base_domain" {
  description = "家庭网络使用的DNS泛域名，例如：home.example.com，表示所有*.home.example.com的域名都解析到家庭网络"
  type        = string
}
