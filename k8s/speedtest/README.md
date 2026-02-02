# LibreSpeed Speedtest Kubernetes 部署

这个 Terraform 模块用于在 Kubernetes 集群中部署 LibreSpeed Speedtest 网络测速服务。

## 功能特性

- 部署 LibreSpeed Speedtest (ghcr.io/librespeed/speedtest:5.4.1)
- 独立的命名空间 (speedtest)
- 可配置的副本数量
- 可配置的资源限制
- 健康检查探针
- ClusterIP 服务
- 可选的遥测数据收集功能

## 关于 LibreSpeed Speedtest

LibreSpeed 是一个开源的网络测速工具，类似于 Speedtest.net，但完全自托管。可以测试:
- 下载速度
- 上传速度
- Ping 延迟
- Jitter（抖动）

## 使用方法

### 1. 配置 Kubernetes Provider

确保你已经在 `../common/` 目录中配置了 Kubernetes provider，或者在使用此模块时提供以下变量:

- `k8s_api_server`: Kubernetes API 服务器地址
- `k8s_cluster_ca_certificate`: 集群 CA 证书
- `k8s_client_key`: 客户端密钥
- `k8s_client_certificate`: 客户端证书

### 2. 使用模块

```hcl
module "speedtest" {
  source = "./k8s/speedtest"

  # Kubernetes 认证配置
  k8s_api_server             = "https://your-k8s-api-server:6443"
  k8s_cluster_ca_certificate = base64decode(var.k8s_cluster_ca_certificate)
  k8s_client_key             = base64decode(var.k8s_client_key)
  k8s_client_certificate     = base64decode(var.k8s_client_certificate)

  # Speedtest 配置（可选，使用默认值）
  speedtest_replicas      = 1
  speedtest_service_type  = "ClusterIP"
  speedtest_service_port  = 80
  speedtest_mode          = "standalone"
  speedtest_telemetry     = "false"
  speedtest_cpu_request   = "100m"
  speedtest_cpu_limit     = "500m"
  speedtest_memory_request = "128Mi"
  speedtest_memory_limit   = "256Mi"
}
```

### 3. 启用遥测功能（可选）

如果想收集测速数据：

```hcl
module "speedtest" {
  source = "./k8s/speedtest"

  # ... 其他配置 ...

  speedtest_telemetry = "true"
  speedtest_password  = "your-secure-password"  # 用于查看遥测数据
  speedtest_email     = "admin@example.com"
}
```

### 4. 初始化和应用

```bash
cd k8s/speedtest
terraform init
terraform plan
terraform apply
```

## 配置变量

| 变量名 | 描述 | 类型 | 默认值 |
|-------|------|------|--------|
| speedtest_image | LibreSpeed Docker 镜像 | string | ghcr.io/librespeed/speedtest:5.4.1 |
| speedtest_replicas | 服务器副本数量 | number | 1 |
| speedtest_service_type | 服务类型 | string | ClusterIP |
| speedtest_service_port | 服务端口 | number | 80 |
| speedtest_mode | 运行模式 | string | standalone |
| speedtest_telemetry | 是否启用遥测 | string | false |
| speedtest_password | 管理员密码 | string | "" |
| speedtest_email | 管理员邮箱 | string | "" |
| speedtest_cpu_request | CPU 请求量 | string | 100m |
| speedtest_cpu_limit | CPU 限制量 | string | 500m |
| speedtest_memory_request | 内存请求量 | string | 128Mi |
| speedtest_memory_limit | 内存限制量 | string | 256Mi |

## 输出值

| 输出名 | 描述 |
|-------|------|
| speedtest_namespace | Speedtest 命名空间名称 |
| speedtest_service_name | Speedtest 服务名称 |
| speedtest_service_port | Speedtest 服务端口 |
| speedtest_service_url | Speedtest 服务访问地址（集群内部） |

## 访问 Speedtest 服务

### 集群内部访问

```
http://librespeed.speedtest.svc.cluster.local
```

### 通过 kubectl port-forward 访问

```bash
kubectl port-forward -n speedtest svc/librespeed 8080:80
```

然后在浏览器中访问 `http://localhost:8080`

### 通过 Gateway API HTTPRoute 暴露（推荐）

此模块支持使用 Gateway API 的 HTTPRoute 来暴露服务，这是 Kubernetes 新一代的流量路由标准。

启用 HTTPRoute:

```hcl
module "speedtest" {
  source = "./k8s/speedtest"

  # ... 其他配置 ...

  speedtest_enable_httproute = true
  speedtest_httproute_host   = "speedtest.yourdomain.com"
  gateway_name               = "nginx-gateway"
  gateway_namespace          = "nginx-gateway"
}
```

或者手动创建 HTTPRoute 资源:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: speedtest-httproute
  namespace: speedtest
spec:
  parentRefs:
  - name: nginx-gateway
    namespace: nginx-gateway
  hostnames:
  - speedtest.yourdomain.com
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: librespeed
      port: 80
```

## 使用测速服务

1. 在浏览器中访问服务地址
2. 点击 "开始测试" 按钮
3. 等待测试完成，查看结果：
   - 下载速度
   - 上传速度
   - Ping 延迟
   - Jitter（抖动）

## 查看遥测数据

如果启用了遥测功能，访问:

```
http://your-speedtest-url/results/stats.php
```

使用配置的密码登录即可查看历史测速数据。

## 维护

### 查看日志

```bash
kubectl logs -n speedtest -l app=librespeed
```

### 查看 Pod 状态

```bash
kubectl get pods -n speedtest
```

### 查看服务状态

```bash
kubectl get svc -n speedtest
```

### 更新部署

修改变量后重新运行:

```bash
terraform apply
```

## 注意事项

1. **资源配置**: 根据预期的并发用户数调整 CPU 和内存限制
2. **网络带宽**: 确保集群有足够的网络带宽进行测速
3. **遥测数据**: 如果启用遥测，建议定期备份数据
4. **密码安全**: 如果启用遥测，请使用强密码

## 故障排查

### Pod 无法启动

```bash
kubectl describe pod -n speedtest -l app=librespeed
```

### 服务无法访问

```bash
kubectl get svc -n speedtest
kubectl describe svc librespeed -n speedtest
```

### 查看完整配置

```bash
kubectl get deployment -n speedtest librespeed -o yaml
```
