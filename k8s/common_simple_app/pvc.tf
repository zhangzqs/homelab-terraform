resource "kubernetes_persistent_volume_claim_v1" "pvc" {
  # 只为没有指定 claim_name 的 volume_mounts 创建新的 PVC
  for_each = {
    for vm in var.volume_mounts :
    vm.name => vm
    if vm.claim_name == null
  }

  depends_on = [
    kubernetes_namespace_v1.namespace
  ]

  metadata {
    name      = "${local.app_name}-${each.value.name}"
    namespace = local.namespace
    labels = {
      app = local.app_name
    }
  }

  spec {
    access_modes = each.value.access_modes

    resources {
      requests = {
        storage = each.value.storage_size
      }
    }

    storage_class_name = each.value.storage_class
  }
}
