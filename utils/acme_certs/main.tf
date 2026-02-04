
resource "acme_registration" "register_account" {
  email_address = var.acme_sh_email
}

resource "acme_certificate" "certificate" {
  account_key_pem = acme_registration.register_account.account_key_pem

  common_name = "*.${var.home_base_domain}"

  dns_challenge {
    provider = var.acme_sh_dns_provider
    config   = var.acme_sh_dns_provider_config
  }
}
