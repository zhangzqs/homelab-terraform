
output "nginx_ssl_certificate" {
  value       = "${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}"
  description = "SSL证书完整链（包含证书和中间证书）给nginx使用"
}

output "nginx_ssl_certificate_key" {
  value       = acme_certificate.certificate.private_key_pem
  description = "SSL证书私钥, 给nginx使用"
}
