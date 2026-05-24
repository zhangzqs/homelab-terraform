# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 仓库性质

这是**纯模块仓库**，只包含可复用的 Terraform 模块。不包含 tfvars、state 文件或部署配置。部署 Stack 配置在私有仓库 `zhangzqs/homelab-terraform-stacks`。

## 模块结构

```
modules/
├── pve/        # Proxmox VE 基础设施（LXC 容器、VM、主机配置）
├── k8s/        # Kubernetes 资源（base 基础组件 + apps 应用）
└── utils/      # 工具模块（证书管理、配置生成器、磁盘挂载等）
```

每个模块是一个独立目录，包含 `main.tf`、`variables.tf`、`outputs.tf`、`versions.tf`。

## 开发命令

```bash
# 格式化（CI 会自动提交格式化结果）
terraform fmt -recursive

# 在单个模块目录下初始化和验证
cd modules/pve/lxcs/code_server
terraform init -backend=false
terraform validate
```

CI 会对所有包含 `.tf` 文件的目录执行 `terraform init -backend=false` + `terraform validate`。

## 约定

- Terraform 版本：1.14
- 模块被外部引用时通过 `github.com/zhangzqs/homelab-terraform//modules/...?ref=master` 格式
- LXC 模块统一使用 `variables.tf` 中的 `pve_*` 变量连接 PVE API
- K8s 模块通过 `k8s_api_server`、`k8s_cluster_ca_certificate` 等变量接收集群连接信息
- 变量描述使用中文
- Git 提交信息遵循 Conventional Commits：`feat(scope): ...`、`fix(scope): ...`、`docs(scope): ...`

### Terraform 编码

- 优先使用 `terraform_data`（内置）替代 `null_resource`，减少 provider 依赖
- module `source` 必须使用纯相对路径，不能包含 `${path.module}` 等插值（Terraform 1.14+ 要求）
- destroy provisioner 中引用变量必须通过 `self` 引用，不能直接引用 `var.*`

## README

README 中的代码统计区域由 CI 自动更新，不要手动修改 `<!-- tokei-start -->` 和 `<!-- tokei-end -->` 之间的内容。
