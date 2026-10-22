# Mihomo 配置校验器

通过 Terraform Action 执行一次性 Docker 容器，使用 Mihomo 内核检查配置。
需要 Terraform 1.14+、`hashicorp/local` 2.9+ 和可用的 Docker daemon。

```hcl
module "validated_mihomo_config" {
  source = "../../homelab-terraform/modules/utils/mihomo_config_validator"

  config_content = module.mihomo_config.config_content
  mihomo_image   = "metacubex/mihomo:v1.19.28" # 可选，默认值相同
}

resource "local_file" "config" {
  filename = "./generated/config.yaml"
  content  = module.validated_mihomo_config.config_content
}

output "config_content" {
  value = module.validated_mihomo_config.config_content
}
```

| 输入 | 说明 |
| --- | --- |
| `config_content` | 必填，待校验的 YAML 配置字符串 |
| `mihomo_image` | 可选，默认 `metacubex/mihomo:v1.19.28`，应与部署端内核一致 |

输出 `config_content` 依赖校验完成，可直接用于文件、部署模块或 root output。
多份配置可在调用模块时使用 `for_each`。

配置内容或镜像变化时，触发 `before_create` / `before_update` Action，以标准输入
执行 `docker run --rm -i <镜像> -t -f -`。无变更的 apply 不重复校验。
校验失败会使 apply 报错，依赖该输出的资源不会收到无效配置。
校验仅检查内核配置解析，不测试代理节点的连通性。
