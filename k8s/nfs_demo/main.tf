# 创建命名空间
resource "kubernetes_namespace_v1" "nfs_demo" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# 创建 NFS PersistentVolume
resource "kubernetes_persistent_volume_v1" "nfs_pv" {
  metadata {
    name = "nfs-pv-demo"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "storage-type"                 = "nfs"
    }
  }

  spec {
    capacity = {
      storage = var.storage_capacity
    }

    access_modes       = ["ReadWriteMany"]
    storage_class_name = "nfs"

    persistent_volume_source {
      nfs {
        server = var.nfs_server_ip
        path   = var.nfs_export_path
      }
    }

    persistent_volume_reclaim_policy = "Retain"
  }
}

# 创建 PersistentVolumeClaim
resource "kubernetes_persistent_volume_claim_v1" "nfs_pvc" {
  metadata {
    name      = "nfs-pvc-demo"
    namespace = kubernetes_namespace_v1.nfs_demo.metadata[0].name
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "nfs"

    resources {
      requests = {
        storage = var.storage_capacity
      }
    }

    volume_name = kubernetes_persistent_volume_v1.nfs_pv.metadata[0].name
  }
}

# 创建一个演示 Pod 来验证 NFS 挂载
resource "kubernetes_pod_v1" "nfs_demo_pod" {
  metadata {
    name      = "nfs-demo-pod"
    namespace = kubernetes_namespace_v1.nfs_demo.metadata[0].name
    labels = {
      "app"                          = "nfs-demo"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    container {
      name  = "busybox"
      image = "busybox:latest"

      command = ["/bin/sh", "-c"]
      args    = ["echo 'NFS Demo Pod is running!' > /mnt/nfs/demo.txt && cat /mnt/nfs/demo.txt && sleep 3600"]

      volume_mount {
        name       = "nfs-volume"
        mount_path = "/mnt/nfs"
      }

      resources {
        limits = {
          cpu    = "100m"
          memory = "64Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "32Mi"
        }
      }
    }

    volume {
      name = "nfs-volume"

      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim_v1.nfs_pvc.metadata[0].name
      }
    }

    restart_policy = "Always"
  }
}
