module "acme_certs" {
  source = "../utils/acme_certs"

  home_base_domain            = var.home_base_domain
  acme_sh_email               = var.acme_sh_email
  acme_sh_dns_provider        = var.acme_sh_dns_provider
  acme_sh_dns_provider_config = var.acme_sh_dns_provider_config

  providers = {
    acme = acme
  }
}
