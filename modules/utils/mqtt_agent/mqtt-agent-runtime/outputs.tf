output "rendered" {
  description = "渲染后的 cloud-init 内容 (base64 编码)"
  value       = base64encode(local.rendered)
}
