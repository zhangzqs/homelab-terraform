module "nginx_config" {
  source = "../utils/nginx_config_generator"

  services = {
    code-server = {
      upstream_inline = {
        servers = [
          {
            address = module.pve_lxc_instance_code_server.code_server_url
            port    = 8080
          }
        ]
      }
      domains = [
        {
          domain       = "code-server.my-domain.local"
          http_enabled = true
        }
      ]
    }
  }
}
