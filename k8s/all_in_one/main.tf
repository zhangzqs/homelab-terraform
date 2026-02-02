
module "ingress_nginx" {
  source = "../ingress-nginx"

  providers = {
    helm = helm
  }
}

module "speedtest" {
  source = "../speedtest"

  speedtest_enable_ingress = true

  providers = {
    kubernetes = kubernetes
  }
}

module "plantuml" {
  source = "../plantuml"

  providers = {
    kubernetes = kubernetes
  }
}
