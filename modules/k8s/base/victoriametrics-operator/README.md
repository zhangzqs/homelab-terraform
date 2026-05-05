# VictoriaMetrics K8s Stack 监控方案

这是一个基于 VictoriaMetrics 的完整 Kubernetes 监控解决方案，包含数据采集、存储、告警和可视化的全套组件。

## 📦 包含组件

### 核心组件
- **VictoriaMetrics Operator**: 管理 VictoriaMetrics 自定义资源的 Kubernetes Operator
- **VMSingle**: 单节点时序数据库，用于存储监控指标
- **VMAgent**: 轻量级数据采集代理，负责抓取和转发指标
- **VMAlert**: 告警规则引擎，基于指标数据触发告警
- **AlertManager**: 告警管理和路由系统

### 可视化组件
- **Grafana**: 监控数据可视化面板，预装 VictoriaMetrics 仪表板

### 数据采集器
- **Prometheus Node Exporter**: 采集节点级别的系统指标
- **Kube State Metrics**: 采集 Kubernetes 集群对象状态

## 🚀 快速开始

### 1. 基础部署

```bash
cd k8s/base/victoriametrics-operator
terraform init
terraform plan
terraform apply
```

### 2. 自定义配置

在您的 Terraform 配置中引用此模块：

```hcl
module "victoriametrics" {
  source = "./k8s/base/victoriametrics-operator"

  # 基础配置
  vm_namespace        = "monitoring"
  vm_retention_period = "30d"

  # 存储配置
  vm_storage_class     = "local-path"
  vmsingle_storage_size = "50Gi"

  # Grafana 配置
  grafana_admin_password = "your-secure-password"
  grafana_service_type   = "NodePort"
  grafana_nodeport       = 30300
  grafana_httproute_enabled   = true
  grafana_httproute_hostnames = ["grafana.example.com"]
  gateway_name                = "shared-gateway"
  gateway_namespace           = "gateway-system"
  grafana_dashboard_data = {
    "custom-dashboard.json" = file("${path.module}/dashboards/custom-dashboard.json")
  }

  # 可选组件
  vmalert_enabled                = true
  alertmanager_enabled           = true
  prometheus_node_exporter_enabled = true
  kube_state_metrics_enabled     = true
}
```

## 🔧 配置说明

### 主要变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `vm_namespace` | `victoriametrics` | 部署的命名空间 |
| `vm_retention_period` | `14d` | 数据保留时间（14天）|
| `vmsingle_storage_size` | `20Gi` | VMSingle 存储容量 |
| `grafana_admin_password` | `admin` | Grafana 管理员密码（生产环境请修改）|
| `grafana_httproute_enabled` | `false` | 是否由模块创建 Grafana 的 HTTPRoute |
| `grafana_httproute_hostnames` | `[]` | Grafana HTTPRoute 域名列表 |
| `gateway_name` | `""` | Grafana HTTPRoute 引用的 Gateway 名称 |
| `gateway_namespace` | `""` | Grafana HTTPRoute 引用的 Gateway 命名空间 |
| `grafana_dashboard_data` | `{}` | 额外注入到 Grafana sidecar 的 dashboard ConfigMap data |
| `grafana_nodeport` | `30300` | Grafana NodePort 端口 |
| `vmalert_enabled` | `true` | 是否启用告警引擎 |
| `alertmanager_enabled` | `true` | 是否启用告警管理器 |

## 📊 访问服务

### Grafana 仪表板

部署完成后，可通过以下方式访问 Grafana：

```bash
# 获取 Grafana 访问信息
terraform output grafana_url
terraform output grafana_admin_user

# 如果是 NodePort 模式
http://<任意节点IP>:30300
```

默认登录凭据：
- 用户名: `admin`
- 密码: 通过 `grafana_admin_password` 变量设置

### VMSingle API

```bash
# 集群内访问
http://vmsingle-victoria-metrics-k8s-stack.victoriametrics.svc:8429

# 端口转发访问
kubectl port-forward -n victoriametrics svc/vmsingle-victoria-metrics-k8s-stack 8429:8429
```

### VMAlert 界面

```bash
kubectl port-forward -n victoriametrics svc/vmalert-victoria-metrics-k8s-stack 8080:8080
# 访问: http://localhost:8080
```

### AlertManager 界面

```bash
kubectl port-forward -n victoriametrics svc/vmalertmanager-victoria-metrics-k8s-stack 9093:9093
# 访问: http://localhost:9093
```

## 🔍 监控指标

自动采集的指标包括：

### Kubernetes 集群指标
- Pod、Deployment、StatefulSet 等资源状态
- 节点资源使用率（CPU、内存、磁盘）
- API Server 性能指标
- Kubelet 运行状态
- 持久卷使用情况

### 系统指标
- 节点 CPU、内存、磁盘、网络使用率
- 文件系统状态
- 系统负载

### 应用指标
- 支持通过 ServiceMonitor 自动发现应用的 Prometheus 指标端点

## 🎯 预置告警规则

包含以下类别的告警规则：

- **节点告警**: CPU、内存、磁盘使用率过高
- **Pod 告警**: Pod 重启频繁、容器崩溃
- **Kubernetes 告警**: API Server 异常、调度器问题
- **存储告警**: PV 容量不足
- **VictoriaMetrics 告警**: 组件健康状态

## 📝 自定义配置

### 添加自定义数据源

可以通过 VMAgent 的 `additionalScrapeConfigs` 添加自定义采集任务：

```yaml
vmagent:
  spec:
    additionalScrapeConfigs:
      - job_name: 'my-app'
        static_configs:
          - targets: ['my-app:8080']
```

### 配置告警通知

编辑 AlertManager 配置添加通知渠道（邮件、Slack、钉钉等）：

```bash
kubectl edit secret -n victoriametrics alertmanager-vmalertmanager-victoria-metrics-k8s-stack
```

## 🔧 维护操作

### 查看组件状态

```bash
# 查看所有组件
kubectl get pods -n victoriametrics

# 查看 VMSingle 状态
kubectl get vmsingle -n victoriametrics

# 查看 VMAgent 状态
kubectl get vmagent -n victoriametrics

# 查看 VMAlert 状态
kubectl get vmalert -n victoriametrics
```

### 扩展存储容量

```bash
# 修改 vmsingle_storage_size 变量后重新应用
terraform apply -var="vmsingle_storage_size=100Gi"
```

### 调整数据保留时间

```bash
terraform apply -var="vm_retention_period=30d"
```

## 📚 参考资料

- [VictoriaMetrics 官方文档](https://docs.victoriametrics.com/)
- [VictoriaMetrics K8s Stack Helm Chart](https://github.com/VictoriaMetrics/helm-charts/tree/master/charts/victoria-metrics-k8s-stack)
- [VictoriaMetrics Operator](https://docs.victoriametrics.com/operator/)
- [Grafana 文档](https://grafana.com/docs/)

## 🐛 故障排查

### 组件无法启动

```bash
# 查看 Operator 日志
kubectl logs -n victoriametrics -l app.kubernetes.io/name=victoria-metrics-operator

# 查看 Pod 事件
kubectl describe pod -n victoriametrics <pod-name>
```

### 数据采集问题

```bash
# 查看 VMAgent 日志
kubectl logs -n victoriametrics -l app.kubernetes.io/name=vmagent

# 检查 ServiceMonitor 资源
kubectl get servicemonitor -n victoriametrics
```

### Grafana 无法访问数据源

```bash
# 检查数据源配置
kubectl get secret -n victoriametrics grafana -o jsonpath='{.data.datasources\.yaml}' | base64 -d

# 测试 VMSingle 连接
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -v http://vmsingle-victoria-metrics-k8s-stack.victoriametrics.svc:8429/api/v1/query?query=up
```

## ⚠️ 生产环境建议

1. **修改默认密码**: 务必更改 Grafana 管理员密码
2. **配置持久化存储**: 使用可靠的 StorageClass（如 Ceph、NFS）
3. **调整资源限制**: 根据集群规模调整各组件的 CPU/内存配置
4. **配置告警通知**: 设置邮件、Slack 等告警渠道
5. **定期备份**: 备份 VMSingle 数据和 Grafana 配置
6. **监控监控系统**: 确保监控组件本身也被监控
7. **增加副本数**: 关键组件（如 VMAgent）可以考虑多副本部署

## 📈 性能优化

- **调整采集间隔**: 通过 `scrapeInterval` 变量控制（默认 30s）
- **数据压缩**: VMSingle 自动压缩数据，可降低 70-90% 存储空间
- **资源限制**: 根据监控指标动态调整各组件的资源配额
- **存储性能**: 使用 SSD 存储提升查询性能
