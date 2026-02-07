resource "helm_release" "csi_driver_nfs" {
  name             = "csi-driver-nfs"
  repository       = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  chart            = "csi-driver-nfs"
  version          = "4.13.0"
  namespace        = "csi-driver-nfs"
  create_namespace = true

  # 等待部署完成
  wait          = true
  wait_for_jobs = true
  timeout       = 300
}
