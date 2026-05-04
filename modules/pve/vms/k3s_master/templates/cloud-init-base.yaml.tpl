#cloud-config
package_update: true
package_upgrade: false

packages:
  - curl
  - openssh-server
  - htop
  - qemu-guest-agent
  - nfs-common

apt:
  sources_list: |
    deb https://mirrors.ustc.edu.cn/ubuntu/ $RELEASE main restricted universe multiverse
    deb https://mirrors.ustc.edu.cn/ubuntu/ $RELEASE-updates main restricted universe multiverse
    deb https://mirrors.ustc.edu.cn/ubuntu/ $RELEASE-backports main restricted universe multiverse
    deb https://mirrors.ustc.edu.cn/ubuntu/ $RELEASE-security main restricted universe multiverse

# 配置用户
disable_root: false
ssh_pwauth: true

# 设置 root 密码
chpasswd:
  list: |
    root:${root_password}
  expire: false

# 配置 SSH 密钥
ssh_authorized_keys:
  - ${ssh_public_key}

runcmd:
  - systemctl enable ssh
  - systemctl restart ssh
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  - sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  - systemctl restart ssh
  - userdel -r ubuntu 2>/dev/null || true
