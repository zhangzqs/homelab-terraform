# PlantUML Server Kubernetes 部署

这个 Terraform 模块用于在 Kubernetes 集群中部署 PlantUML Server。

## 功能特性

- 部署 PlantUML Server (plantuml/plantuml-server:jetty-v1.2025.2)
- 独立的命名空间 (plantuml)
- 可配置的副本数量
- 可配置的资源限制
- 健康检查探针
- ClusterIP 服务

## 使用方法

### 1. 配置 Kubernetes Provider

确保你已经在 `../common/` 目录中配置了 Kubernetes provider，或者在使用此模块时提供以下变量:

- `k8s_api_server`: Kubernetes API 服务器地址
- `k8s_cluster_ca_certificate`: 集群 CA 证书
- `k8s_client_key`: 客户端密钥
- `k8s_client_certificate`: 客户端证书

### 2. 使用模块

```hcl
module "plantuml" {
  source = "./k8s/plantuml"

  # Kubernetes 认证配置
  k8s_api_server             = "https://your-k8s-api-server:6443"
  k8s_cluster_ca_certificate = base64decode(var.k8s_cluster_ca_certificate)
  k8s_client_key             = base64decode(var.k8s_client_key)
  k8s_client_certificate     = base64decode(var.k8s_client_certificate)

  # PlantUML 配置（可选，使用默认值）
  plantuml_replicas      = 2
  plantuml_service_type  = "ClusterIP"
  plantuml_service_port  = 8080
  plantuml_cpu_request   = "200m"
  plantuml_cpu_limit     = "1000m"
  plantuml_memory_request = "512Mi"
  plantuml_memory_limit   = "1Gi"
}
```

### 3. 初始化和应用

```bash
cd k8s/plantuml
terraform init
terraform plan
terraform apply
```

## 配置变量

| 变量名 | 描述 | 类型 | 默认值 |
|-------|------|------|--------|
| plantuml_image | PlantUML 服务器 Docker 镜像 | string | plantuml/plantuml-server:jetty-v1.2025.2 |
| plantuml_replicas | PlantUML 服务器副本数量 | number | 1 |
| plantuml_service_type | 服务类型 | string | ClusterIP |
| plantuml_service_port | 服务端口 | number | 8080 |
| plantuml_cpu_request | CPU 请求量 | string | 100m |
| plantuml_cpu_limit | CPU 限制量 | string | 500m |
| plantuml_memory_request | 内存请求量 | string | 256Mi |
| plantuml_memory_limit | 内存限制量 | string | 512Mi |

## 输出值

| 输出名 | 描述 |
|-------|------|
| plantuml_namespace | PlantUML 命名空间名称 |
| plantuml_service_name | PlantUML 服务名称 |
| plantuml_service_port | PlantUML 服务端口 |
| plantuml_service_url | PlantUML 服务访问地址（集群内部） |

## 访问 PlantUML Server

### 集群内部访问

```
http://plantuml-server.plantuml.svc.cluster.local:8080
```

### 通过 kubectl port-forward 访问

```bash
kubectl port-forward -n plantuml svc/plantuml-server 8080:8080
```

然后在浏览器中访问 `http://localhost:8080`

### 通过 Gateway API HTTPRoute 暴露（推荐）

此模块支持使用 Gateway API 的 HTTPRoute 来暴露服务，这是 Kubernetes 新一代的流量路由标准。

启用 HTTPRoute:

```hcl
module "plantuml" {
  source = "./k8s/plantuml"

  # ... 其他配置 ...

  plantuml_enable_httproute = true
  plantuml_httproute_host   = "plantuml.yourdomain.com"
  gateway_name              = "nginx-gateway"
  gateway_namespace         = "nginx-gateway"
}
```

或者手动创建 HTTPRoute 资源:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: plantuml-httproute
  namespace: plantuml
spec:
  parentRefs:
  - name: nginx-gateway
    namespace: nginx-gateway
  hostnames:
  - plantuml.yourdomain.com
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: plantuml-server
      port: 8080
```

## 测试 PlantUML

访问 PlantUML Server 后，你可以使用以下 URL 格式生成图表:

```
http://plantuml-server:8080/png/<encoded-diagram>
```

或者使用 Web 界面生成图表。

## 维护

### 查看日志

```bash
kubectl logs -n plantuml -l app=plantuml-server
```

### 查看 Pod 状态

```bash
kubectl get pods -n plantuml
```

### 更新部署

修改变量后重新运行:

```bash
terraform apply
```
