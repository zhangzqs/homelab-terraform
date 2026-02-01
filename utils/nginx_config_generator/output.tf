locals {
  # 生成nginx主配置文件
  nginx_conf_content = templatefile("${path.module}/nginx.conf.tpl", {
    worker_processes     = var.worker_processes
    worker_connections   = var.worker_connections
    enable_vts           = var.enable_vts
    vts_status_port      = var.vts_status_port
    enable_gzip          = var.enable_gzip
    log_format           = var.log_format
    custom_global_config = var.custom_global_config
  })

  # 生成upstream配置文件
  upstream_conf_content = templatefile("${path.module}/upstream.conf.tpl", {
    upstreams = var.upstreams
  })

  # 为每个服务生成独立的server配置文件
  server_configs = {
    for service_name, service in var.services :
    service_name => templatefile("${path.module}/server.conf.tpl", {
      service_name = service_name
      upstream     = service.upstream
      domains      = service.domains
      locations    = service.locations
      proxy_config = merge({
        enable_websocket     = true
        connect_timeout      = "200ms"
        read_timeout         = "1000s"
        send_timeout         = "1000s"
        client_max_body_size = "8192M"
        proxy_buffering      = false
      }, service.proxy_config)
      custom_server_config      = service.custom_server_config
      ssl_protocols             = var.ssl_common_config.protocols != null ? var.ssl_common_config.protocols : "TLSv1.2 TLSv1.3"
      ssl_ciphers               = var.ssl_common_config.ciphers != null ? var.ssl_common_config.ciphers : "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
      ssl_prefer_server_ciphers = var.ssl_common_config.prefer_server_ciphers != null ? var.ssl_common_config.prefer_server_ciphers : true
      ssl_session_cache         = var.ssl_common_config.session_cache != null ? var.ssl_common_config.session_cache : "shared:SSL:10m"
      ssl_session_timeout       = var.ssl_common_config.session_timeout != null ? var.ssl_common_config.session_timeout : "10m"
    })
  }
}

output "nginx_conf" {
  description = "Nginx主配置文件内容"
  value       = local.nginx_conf_content
}

output "upstream_conf" {
  description = "Upstream配置文件内容"
  value       = local.upstream_conf_content
}

output "server_configs" {
  description = "各服务的server配置文件内容，key为服务名"
  value       = local.server_configs
}

output "all_configs" {
  description = "所有配置文件的映射，用于批量写入文件"
  value = merge(
    {
      "nginx.conf"           = local.nginx_conf_content
      "conf.d/upstream.conf" = local.upstream_conf_content
    },
    {
      for service_name, content in local.server_configs :
      "conf.d/servers/${service_name}.conf" => content
    }
  )
}
