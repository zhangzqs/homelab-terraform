resource "kubernetes_namespace_v1" "plantuml" {
  metadata {
    name = "plantuml"
    labels = {
      name = "plantuml"
      app  = "plantuml-server"
    }
  }
}
