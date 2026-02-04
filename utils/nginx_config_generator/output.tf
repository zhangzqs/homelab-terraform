locals {
  # 生成nginx主配置文件
  nginx_conf_content = templatefile("${path.module}/templates/nginx.conf.tpl", {
    worker_processes   = var.worker_processes
    worker_connections = var.worker_connections
    enable_vts         = var.enable_vts
    vts_status_port    = var.vts_status_port
    enable_gzip        = var.enable_gzip
    log_format         = var.log_format
    access_log_path    = var.access_log_path
    error_log_path     = var.error_log_path
    error_log_level    = var.error_log_level
  })

  # 从services中提取内联的upstream配置，并为其生成唯一名称
  inline_upstreams = {
    for service_name, service in var.services :
    "${service_name}_upstream" => service.upstream_inline
    if service.upstream_inline != null
  }

  # 合并共享upstreams和内联upstreams
  all_upstreams = merge(var.shared_upstreams, local.inline_upstreams)

  # 为每个服务确定其实际使用的upstream名称
  service_upstream_map = {
    for service_name, service in var.services :
    service_name => service.upstream_ref != "" ? service.upstream_ref : "${service_name}_upstream"
  }

  # 生成upstream配置文件
  upstream_conf_content = templatefile("${path.module}/templates/upstream.conf.tpl", {
    upstreams = local.all_upstreams
  })

  # 为每个服务生成独立的server配置内容
  server_config_contents = {
    for service_name, service in var.services :
    service_name => templatefile("${path.module}/templates/server.conf.tpl", {
      service_name = service_name
      upstream     = local.service_upstream_map[service_name]
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
      ssl_protocols             = var.ssl_common_config.protocols != null ? var.ssl_common_config.protocols : "TLSv1.2 TLSv1.3"
      ssl_ciphers               = var.ssl_common_config.ciphers != null ? var.ssl_common_config.ciphers : "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
      ssl_prefer_server_ciphers = var.ssl_common_config.prefer_server_ciphers != null ? var.ssl_common_config.prefer_server_ciphers : true
      ssl_session_cache         = var.ssl_common_config.session_cache != null ? var.ssl_common_config.session_cache : "shared:SSL:10m"
      ssl_session_timeout       = var.ssl_common_config.session_timeout != null ? var.ssl_common_config.session_timeout : "10m"
    })
  }

  # 合并所有server配置为单个文件
  servers_conf_content = join("\n", [
    for service_name in sort(keys(local.server_config_contents)) :
    local.server_config_contents[service_name]
  ])
}

output "nginx_conf" {
  description = "Nginx主配置文件内容"
  value       = local.nginx_conf_content
}

output "upstream_conf" {
  description = "Upstream配置文件内容"
  value       = local.upstream_conf_content
}

output "servers_conf" {
  description = "所有服务的server配置合并后的内容（单个文件）"
  value       = local.servers_conf_content
}

output "server_configs" {
  description = "各服务的server配置文件内容（按服务名分组，用于需要分离文件的场景）"
  value       = local.server_config_contents
}

output "all_configs" {
  description = "所有配置文件的映射，用于批量写入文件"
  value = {
    "nginx.conf"           = local.nginx_conf_content
    "conf.d/upstream.conf" = local.upstream_conf_content
    "conf.d/servers.conf"  = local.servers_conf_content
  }
}
