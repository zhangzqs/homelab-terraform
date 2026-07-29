variable "httproute_hostname" { type = string }
variable "gateway_name" { type = string }
variable "gateway_namespace" { type = string }
variable "storage_class_name" { type = string }
variable "postgres_password" {
  type      = string
  sensitive = true
}
variable "redis_password" {
  type      = string
  sensitive = true
}
variable "session_secret" {
  type      = string
  sensitive = true
}
variable "crypto_secret" {
  type      = string
  sensitive = true
}
variable "postgres_storage_size" {
  type    = string
  default = "10Gi"
}
variable "data_storage_size" {
  type    = string
  default = "5Gi"
}
variable "logs_storage_size" {
  type    = string
  default = "5Gi"
}
