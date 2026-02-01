resource "kubernetes_namespace" "plantuml" {
  metadata {
    name = "plantuml"
    labels = {
      name = "plantuml"
      app  = "plantuml-server"
    }
  }
}
