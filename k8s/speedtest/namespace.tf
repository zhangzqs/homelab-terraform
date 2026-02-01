resource "kubernetes_namespace_v1" "speedtest" {
  metadata {
    name = "speedtest"
    labels = {
      name = "speedtest"
      app  = "librespeed"
    }
  }
}
