resource "kubernetes_namespace" "speedtest" {
  metadata {
    name = "speedtest"
    labels = {
      name = "speedtest"
      app  = "librespeed"
    }
  }
}
