# Gateway API Kubernetes 部署

这个 Terraform 模块用于在 Kubernetes 集群中部署 Gateway API 控制器 (NGINX Gateway Fabric)，替代传统的 Ingress Nginx 控制器。

## 功能特性

- 部署 NGINX Gateway Fabric 作为 Gateway API 控制器
- 创建默认的 Gateway 资源
- 支持 NodePort 和 LoadBalancer 服务类型
- 可配置的资源限制
- 支持跨命名空间的 HTTPRoute

## 关于 Gateway API

Gateway API 是 Kubernetes 新一代的流量路由标准，相比传统的 Ingress 具有以下优势：

- **更丰富的功能**：支持更多的流量管理功能，如请求头匹配、权重路由等
- **角色分离**：支持基础设施管理员和应用开发者的职责分离
- **可移植性**：不同实现之间具有更好的一致性
- **可扩展性**：支持自定义资源扩展

## 使用方法

### 1. 配置 Kubernetes Provider

确保你已经在 `../common/` 目录中配置了 Kubernetes provider，或者在使用此模块时提供以下变量:

- `k8s_api_server`: Kubernetes API 服务器地址
- `k8s_cluster_ca_certificate`: 集群 CA 证书
- `k8s_client_key`: 客户端密钥
- `k8s_client_certificate`: 客户端证书

### 2. 使用模块

```hcl
module "gateway_api" {
  source = "./k8s/gateway-api"

  # Kubernetes 认证配置
  k8s_api_server             = "https://your-k8s-api-server:6443"
  k8s_cluster_ca_certificate = base64decode(var.k8s_cluster_ca_certificate)
  k8s_client_key             = base64decode(var.k8s_client_key)
  k8s_client_certificate     = base64decode(var.k8s_client_certificate)

  # Gateway API 配置（可选，使用默认值）
  gateway_api_namespace = "nginx-gateway"
  gateway_name          = "nginx-gateway"
  gateway_service_type  = "NodePort"
  gateway_http_nodeport = 30080
  gateway_https_nodeport = 30443
}
```

### 3. 初始化和应用

```bash
cd k8s/gateway-api
terraform init
terraform plan
terraform apply
```

## 配置变量

| 变量名 | 描述 | 类型 | 默认值 |
|-------|------|------|--------|
| gateway_api_namespace | Gateway API 命名空间 | string | nginx-gateway |
| nginx_gateway_fabric_chart_version | NGINX Gateway Fabric Helm Chart 版本 | string | 1.6.2 |
| gateway_name | Gateway 资源名称 | string | nginx-gateway |
| gateway_service_type | Gateway Service 类型 | string | NodePort |
| gateway_http_nodeport | HTTP NodePort 端口号 | number | 30080 |
| gateway_https_nodeport | HTTPS NodePort 端口号 | number | 30443 |

## 输出值

| 输出名 | 描述 |
|-------|------|
| gateway_api_namespace | Gateway API 命名空间 |
| gateway_api_status | NGINX Gateway Fabric 部署状态 |
| gateway_api_version | NGINX Gateway Fabric Chart 版本 |
| gateway_name | Gateway 资源名称 |
| gateway_http_nodeport | Gateway HTTP NodePort |
| gateway_https_nodeport | Gateway HTTPS NodePort |

## 使用 HTTPRoute 路由流量

创建 HTTPRoute 将流量路由到后端服务:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app-route
  namespace: my-app
spec:
  parentRefs:
  - name: nginx-gateway
    namespace: nginx-gateway
  hostnames:
  - myapp.example.com
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: my-service
      port: 80
```

## 维护

### 查看 Gateway 状态

```bash
kubectl get gateway -n nginx-gateway
kubectl describe gateway nginx-gateway -n nginx-gateway
```

### 查看 HTTPRoute

```bash
kubectl get httproute -A
```

### 查看日志

```bash
kubectl logs -n nginx-gateway -l app.kubernetes.io/name=nginx-gateway-fabric
```

### 查看 Pod 状态

```bash
kubectl get pods -n nginx-gateway
```

### 更新部署

修改变量后重新运行:

```bash
terraform apply
```

## 从 Ingress Nginx 迁移

如果你之前使用 Ingress Nginx，请按以下步骤迁移：

1. 部署 Gateway API 模块
2. 将 `kubernetes_ingress_v1` 资源替换为 `kubernetes_manifest` 资源（HTTPRoute）
3. 更新相关变量名（如 `*_enable_ingress` 改为 `*_enable_httproute`）
4. 测试新的路由规则
5. 移除旧的 Ingress Nginx 模块

## 故障排查

### Gateway 无法启动

```bash
kubectl describe gateway nginx-gateway -n nginx-gateway
kubectl get events -n nginx-gateway
```

### HTTPRoute 不生效

```bash
kubectl describe httproute <name> -n <namespace>
```

检查 HTTPRoute 的状态条件，确保已被 Gateway 接受。

### 查看完整配置

```bash
kubectl get gateway nginx-gateway -n nginx-gateway -o yaml
kubectl get httproute -A -o yaml
```
