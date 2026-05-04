locals {
  // 通过 local 定义常用的资源名称，方便在模块中引用
  namespace = var.namespace != null ? var.namespace : var.app_name

  app_name        = var.app_name
  svc_name        = local.app_name
  deployment_name = local.app_name
  httproute_name  = local.app_name

  container_name = var.container_name != null ? var.container_name : local.app_name
}
