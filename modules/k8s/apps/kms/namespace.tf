resource "kubernetes_namespace_v1" "namespace" {
  metadata {
    name = local.namespace
  }
}
