# 存储持久化配置说明

## 📦 持久化组件概览

| 组件 | 持久化 | 默认大小 | StorageClass | 数据路径 | 说明 |
|------|--------|---------|-------------|----------|------|
| **VMSingle** | ✅ | 20Gi | local-path | `/victoria-metrics-data` | 时序数据库，存储所有监控指标 |
| **Grafana** | ✅ | 5Gi | local-path | `/var/lib/grafana` | 仪表板配置、用户设置、插件 |
| **AlertManager** | ✅ | 2Gi | local-path | `/alertmanager` | 告警历史、静默规则 |
| VMAgent | ❌ | - | - | - | 无状态采集代理，无需持久化 |
| VMAlert | ❌ | - | - | - | 无状态告警引擎，规则存在 ConfigMap |

## 🗂️ local-path StorageClass 详解

### 默认配置

`local-path` 是 Kubernetes 集群中常用的本地存储类，通常由以下工具提供：

- **K3s**: 自带 local-path-provisioner
- **Kind**: 内置支持
- **手动部署**: Rancher Local Path Provisioner

### 数据存储位置

#### K3s 环境
```bash
# 默认路径
/var/lib/rancher/k3s/storage/

# PVC 数据结构示例
/var/lib/rancher/k3s/storage/
├── pvc-<uuid>_<namespace>_<pvc-name>/
│   ├── db/                          # VMSingle 数据
│   ├── wal/                         # Write-Ahead Log
│   └── cache/                       # 缓存数据
├── pvc-<uuid>_victoriametrics_grafana-pvc/
│   ├── grafana.db                   # Grafana 数据库
│   ├── dashboards/                  # 仪表板
│   └── plugins/                     # 插件
└── pvc-<uuid>_victoriametrics_alertmanager-pvc/
    └── data/                        # AlertManager 数据
```

#### 自定义部署环境
```bash
# 默认路径
/opt/local-path-provisioner/

# 查看配置
kubectl get configmap -n kube-system local-path-config -o yaml
```

### 查看实际存储位置

```bash
# 1. 查看 PVC
kubectl get pvc -n victoriametrics

# 2. 查看 PV 详情（包含实际路径）
kubectl get pv -o custom-columns=\
NAME:.metadata.name,\
CAPACITY:.spec.capacity.storage,\
PATH:.spec.local.path,\
STORAGECLASS:.spec.storageClassName

# 3. 在节点上查看数据
# 首先找到 Pod 所在节点
kubectl get pods -n victoriametrics -o wide

# SSH 到该节点后查看
ls -lh /var/lib/rancher/k3s/storage/  # K3s
# 或
ls -lh /opt/local-path-provisioner/   # 标准部署
```

## 📊 存储空间规划

### 推荐配置（根据集群规模）

#### 小型集群 (< 10 节点)
```hcl
vmsingle_storage_size        = "20Gi"   # 2周数据
grafana_storage_size          = "2Gi"    # 足够存储仪表板
alertmanager_storage_size     = "1Gi"    # 基本够用
vm_retention_period           = "14d"    # 保留14天
```

#### 中型集群 (10-50 节点)
```hcl
vmsingle_storage_size        = "50Gi"   # 1个月数据
grafana_storage_size          = "5Gi"
alertmanager_storage_size     = "2Gi"
vm_retention_period           = "30d"    # 保留30天
```

#### 大型集群 (> 50 节点)
```hcl
vmsingle_storage_size        = "200Gi"  # 3个月数据
grafana_storage_size          = "10Gi"
alertmanager_storage_size     = "5Gi"
vm_retention_period           = "90d"    # 保留90天
```

### 计算 VMSingle 存储大小

**估算公式**：
```
存储大小 = 每秒采样数 × 样本大小 × 保留秒数 × 压缩比

其中：
- 每秒采样数 ≈ 时间序列数量 ÷ 采集间隔(秒)
- 样本大小 ≈ 1-2 bytes (VictoriaMetrics 高度压缩)
- 保留秒数 = retention_period 转换为秒
- 压缩比 ≈ 0.1-0.3 (相比 Prometheus)
```

**实际案例**：
- 集群规模: 20 节点
- 监控指标: 约 5000 个时间序列
- 采集间隔: 30 秒
- 保留时间: 14 天

计算：
```
5000 序列 × 2 bytes × 14天 × 86400秒/天 ÷ 30秒
= 5000 × 2 × 1,209,600 ÷ 30
≈ 403MB × 压缩比(0.2)
≈ 80MB 实际占用

建议配置 20Gi (留有大量余量)
```

## 🔧 配置变量

### 启用/禁用持久化

```hcl
module "victoriametrics" {
  source = "./k8s/base/victoriametrics-operator"

  # Grafana 持久化（默认启用）
  grafana_storage_enabled = true
  grafana_storage_size    = "5Gi"

  # AlertManager 持久化（默认启用）
  alertmanager_storage_enabled = true
  alertmanager_storage_size    = "2Gi"

  # VMSingle 持久化（必需）
  vmsingle_storage_size = "50Gi"
  vm_retention_period   = "30d"
}
```

### 使用不同的 StorageClass

如果你有其他 StorageClass（如 NFS、Ceph、LongHorn）：

```hcl
module "victoriametrics" {
  source = "./k8s/base/victoriametrics-operator"

  # 使用网络存储
  vm_storage_class = "longhorn"  # 或 "nfs-client", "ceph-rbd" 等

  # 网络存储可以设置更大容量
  vmsingle_storage_size = "100Gi"
}
```

## 🔍 监控存储使用情况

### 查看 PVC 使用率

```bash
# 安装 kubectl-df-pv 插件（可选）
kubectl krew install df-pv

# 查看 PVC 使用情况
kubectl df-pv -n victoriametrics

# 或使用原生方法
kubectl exec -n victoriametrics <vmsingle-pod> -- df -h /victoria-metrics-data
```

### 在 Grafana 中查看

部署后 Grafana 会自动包含存储监控仪表板，显示：
- PV 使用率
- 磁盘 I/O
- 数据增长趋势
- 预计可用时间

## 🚨 存储扩容

### 方法 1: 修改 PVC（需要 StorageClass 支持 allowVolumeExpansion）

```bash
# 1. 检查 StorageClass 是否支持扩容
kubectl get storageclass local-path -o jsonpath='{.allowVolumeExpansion}'
# 如果输出 true，则支持

# 2. 编辑 PVC
kubectl edit pvc -n victoriametrics vmstorage-vmsingle-victoria-metrics-k8s-stack-0

# 3. 修改 spec.resources.requests.storage 为新的大小
# 保存后会自动扩容
```

### 方法 2: 修改 Terraform 配置

```hcl
# 修改变量
vmsingle_storage_size = "50Gi"  # 从 20Gi 改为 50Gi

# 应用变更
terraform apply
```

⚠️ **注意**: local-path 默认**不支持**在线扩容，需要：
1. 备份数据
2. 删除 PVC
3. 重新创建更大的 PVC
4. 恢复数据

### 方法 3: 迁移到支持扩容的 StorageClass

推荐使用支持动态扩容的存储方案：
- **Longhorn**: 云原生分布式块存储（推荐）
- **OpenEBS**: 容器化存储
- **Ceph RBD**: 企业级分布式存储
- **NFS**: 简单的网络存储

## 🔒 数据备份与恢复

### VMSingle 数据备份

```bash
# 方法 1: 使用 vmbackup 工具（推荐）
kubectl exec -n victoriametrics vmsingle-victoria-metrics-k8s-stack-0 -- \
  /vmbackup-prod \
  -storageDataPath=/victoria-metrics-data \
  -dst=fs:///backup/$(date +%Y%m%d)

# 方法 2: 快照备份（如果使用支持快照的 StorageClass）
kubectl create volumesnapshot vmsingle-snapshot \
  --volumesnapshotclass=<snapshot-class> \
  --pvc=vmstorage-vmsingle-victoria-metrics-k8s-stack-0 \
  -n victoriametrics

# 方法 3: 直接复制数据目录
# 先找到 Pod 所在节点和 PV 路径
kubectl get pv -o wide
# SSH 到节点
tar czf vmsingle-backup-$(date +%Y%m%d).tar.gz /var/lib/rancher/k3s/storage/pvc-*/
```

### Grafana 配置备份

```bash
# 备份 Grafana 数据库
kubectl exec -n victoriametrics deploy/victoria-metrics-k8s-stack-grafana -- \
  tar czf - /var/lib/grafana > grafana-backup-$(date +%Y%m%d).tar.gz

# 或使用 Grafana API 导出仪表板
# 获取 admin 密码
kubectl get secret -n victoriametrics victoria-metrics-k8s-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d

# 使用 API 导出
curl -u admin:<password> http://<grafana-url>/api/search | \
  jq -r '.[].uri' | \
  xargs -I {} curl -u admin:<password> http://<grafana-url>/api/dashboards/{} > dashboards-backup.json
```

## ⚠️ 注意事项

### local-path 的限制

1. **节点绑定**: 数据存储在特定节点，Pod 调度受限
   - 解决方案: 使用 nodeAffinity 或迁移到网络存储

2. **无冗余**: 节点故障导致数据丢失
   - 解决方案: 定期备份或使用分布式存储

3. **无法跨节点**: Pod 不能自由迁移
   - 解决方案: 使用 NFS/Ceph 等网络存储

4. **扩容困难**: 不支持在线扩容
   - 解决方案: 使用 Longhorn 等支持扩容的存储

### 生产环境建议

- ✅ 使用支持快照和扩容的 StorageClass
- ✅ 配置自动备份任务
- ✅ 监控存储使用率并设置告警
- ✅ 定期测试备份恢复流程
- ✅ 考虑使用对象存储作为长期归档

## 📚 参考资料

- [VictoriaMetrics Backup](https://docs.victoriametrics.com/vmbackup.html)
- [Local Path Provisioner](https://github.com/rancher/local-path-provisioner)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [Kubernetes PV Expansion](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#expanding-persistent-volumes-claims)
