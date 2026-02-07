# SSH 连接配置
ssh_host = "192.168.1.100"
ssh_port = 22
ssh_user = "root"

# SSH 认证方式（二选一）
# 方式1: 使用密码认证（不推荐）
ssh_password = "your_password_here"

# 磁盘配置
# 通过以下命令获取磁盘UUID: sudo blkid
disk_uuid       = "550e8400-e29b-41d4-a716-446655440000"  # 替换为实际的UUID（使用 blkid 命令查看）
disk_label      = "usb-disk"
mount_point     = "/mnt/usb-disk"
filesystem_type = "ext4"  # ext4, ntfs, exfat, vfat, xfs 等

# 挂载选项
mount_options = "defaults,nofail"

# 自动挂载配置
automount_enabled = true  # true: 按需挂载, false: 立即挂载
automount_timeout = 300   # 秒，0表示永不超时卸载

# 权限配置
owner       = "root"
group       = "root"
permissions = "755"
