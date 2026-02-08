#!/bin/bash
set -e

# 解析启用的协议参数
ENABLED_PROTOCOLS=("$@")

echo 'Performing internal LXC configuration...'
sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list
sed -i 's/http:/https:/g' /etc/apt/sources.list

# 基础软件包
BASE_PACKAGES="curl openssh-server htop language-pack-zh-hans jq"

# 根据启用的协议添加相应的软件包
STORAGE_PACKAGES=""
for protocol in "${ENABLED_PROTOCOLS[@]}"; do
  case "$protocol" in
    nfs)
      STORAGE_PACKAGES="$STORAGE_PACKAGES nfs-kernel-server"
      ;;
    smb)
      STORAGE_PACKAGES="$STORAGE_PACKAGES podman"
      ;;
    *)
      echo "Warning: Unknown protocol '$protocol'"
      ;;
  esac
done

echo "Installing packages: $BASE_PACKAGES $STORAGE_PACKAGES"
apt-get update && apt-get install -y $BASE_PACKAGES $STORAGE_PACKAGES

# 配置 SSH 允许 root 密码登录
echo "Configuring SSH for root password login..."
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# 启用并启动相应的服务
for protocol in "${ENABLED_PROTOCOLS[@]}"; do
  case "$protocol" in
    nfs)
      echo "Enabling NFS service..."
      systemctl enable nfs-kernel-server
      systemctl start nfs-kernel-server
      ;;
    smb)
      echo "Podman installed for SMB (container will be managed by Terraform)"
      # 配置 Podman 支持 Docker API
      systemctl enable podman.socket
      systemctl start podman.socket
      ;;
  esac
done

echo "Storage Server setup completed. Enabled protocols: ${ENABLED_PROTOCOLS[*]}"

# 创建独立的语言配置文件
sudo tee /etc/profile.d/lang.sh > /dev/null << 'EOF'
#!/bin/bash
# 设置中文环境变量，幂等实现
if [ -z "$LANG" ]; then
    export LANG=zh_CN.UTF-8
elif [[ "$LANG" != *zh_CN.UTF-8* && "$LANG" != *zh_CN.utf8* ]]; then
    # 如果已设置但不是中文UTF-8，可选择性强制设置
    # export LANG=zh_CN.UTF-8
    :
fi

if [ -z "$LC_ALL" ]; then
    export LC_ALL=zh_CN.UTF-8
elif [[ "$LC_ALL" != *zh_CN.UTF-8* && "$LC_ALL" != *zh_CN.utf8* ]]; then
    # 如果已设置但不是中文UTF-8，可选择性强制设置
    # export LC_ALL=zh_CN.UTF-8
    :
fi
EOF

# 确保可执行权限
chmod +x /etc/profile.d/lang.sh