# 部署 VictoriaMetrics Operator
resource "helm_release" "victoria_metrics_operator" {
  name             = "victoria-metrics-operator"
  repository       = "https://victoriametrics.github.io/helm-charts/"
  chart            = "victoria-metrics-operator"
  version          = "0.58.1"
  namespace        = var.vm_namespace
  create_namespace = true

  values = [
    yamlencode({
      operator = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }
    })
  ]
}

# 部署 VictoriaMetrics K8s Stack (完整监控方案)
resource "helm_release" "victoria_metrics_k8s_stack" {
  name       = "victoria-metrics-k8s-stack"
  repository = "https://victoriametrics.github.io/helm-charts/"
  chart      = "victoria-metrics-k8s-stack"
  version    = "0.70.0"
  namespace  = var.vm_namespace

  values = [
    yamlencode({
      # VictoriaMetrics Single - 单节点时序数据库
      vmsingle = {
        enabled = true
        spec = {
          retentionPeriod = var.vm_retention_period
          replicaCount    = 1
          storage = {
            storageClassName = var.vm_storage_class
            resources = {
              requests = {
                storage = var.vmsingle_storage_size
              }
            }
          }
          resources = {
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "1000m"
              memory = "2Gi"
            }
          }
        }
      }

      # VMAgent - 数据采集代理
      vmagent = {
        enabled = true
        spec = {
          replicaCount = 1
          resources = {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }
          # 配置远程写入到 vmsingle
          remoteWrite = [
            {
              url = "http://vmsingle-victoria-metrics-k8s-stack.${var.vm_namespace}.svc:8429/api/v1/write"
            }
          ]
        }
      }

      # VMAlert - 告警规则引擎
      vmalert = {
        enabled = var.vmalert_enabled
        spec = {
          replicaCount = 1
          datasource = {
            url = "http://vmsingle-victoria-metrics-k8s-stack.${var.vm_namespace}.svc:8429"
          }
          notifier = {
            url = "http://vmalertmanager-victoria-metrics-k8s-stack.${var.vm_namespace}.svc:9093"
          }
          resources = {
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "512Mi"
            }
          }
        }
      }

      # AlertManager - 告警管理
      alertmanager = {
        enabled = var.alertmanager_enabled
        spec = {
          replicaCount = 1
          storage = var.alertmanager_storage_enabled ? {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.vm_storage_class
                resources = {
                  requests = {
                    storage = var.alertmanager_storage_size
                  }
                }
              }
            }
          } : null
          resources = {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }
        }
      }

      # Grafana - 可视化面板
      grafana = {
        enabled        = true
        adminPassword  = var.grafana_admin_password
        persistence = var.grafana_storage_enabled ? {
          enabled          = true
          storageClassName = var.vm_storage_class
          size             = var.grafana_storage_size
        } : {
          enabled = false
        }
        sidecar = {
          datasources = {
            enabled       = true
            defaultDatasource = true
          }
          dashboards = {
            enabled = true
            searchNamespace = "ALL"
          }
        }
        service = {
          type = var.grafana_service_type
          nodePort = var.grafana_nodeport
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }
        # 预装 VictoriaMetrics 相关仪表板
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [
              {
                name            = "default"
                orgId           = 1
                folder          = ""
                type            = "file"
                disableDeletion = false
                editable        = true
                options = {
                  path = "/var/lib/grafana/dashboards/default"
                }
              }
            ]
          }
        }
      }

      # Prometheus Node Exporter - 节点指标采集
      "prometheus-node-exporter" = {
        enabled = var.prometheus_node_exporter_enabled
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "128Mi"
          }
        }
      }

      # Kube State Metrics - K8s 集群状态指标
      "kube-state-metrics" = {
        enabled = var.kube_state_metrics_enabled
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }

      # 默认的 ServiceMonitor 配置
      defaultRules = {
        create = true
        rules = {
          # Kubernetes 相关规则
          kubeApiserver          = true
          kubeApiserverAvailability = true
          kubeApiserverSlos      = true
          kubeControllerManager  = true
          kubeScheduler         = true
          kubeStateMetrics      = true
          kubelet               = true
          kubernetesApps        = true
          kubernetesResources   = true
          kubernetesStorage     = true
          kubernetesSystem      = true
          node                  = true
          # VictoriaMetrics 相关规则
          vmhealth              = true
        }
      }

      # ServiceMonitor 选择器
      serviceMonitor = {
        enabled = true
      }

      # Scrape 配置
      scrapeInterval = "30s"
      evaluationInterval = "30s"
    })
  ]

  depends_on = [helm_release.victoria_metrics_operator]
}
