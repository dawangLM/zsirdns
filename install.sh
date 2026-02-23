#!/bin/bash

# zsirdns 一键安装脚本
# 仓库地址: https://github.com/dawangLM/zsirdns.git

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

echo -e "${BLUE}🚀 欢迎使用 zsirdns 一键安装脚本！${PLAIN}"

# 1. 环境检查
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误: 必须使用 root 权限运行此脚本！${PLAIN}" 
   exit 1
fi

# 2. 安装依赖
echo -e "${GREEN}正在安装基础依赖 (git, curl, wget, nftables)...${PLAIN}"
apt update && apt install -y git curl wget nftables grep

# 3. 克隆仓库
INSTALL_DIR="/etc/zsirdns"
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${BLUE}目录 $INSTALL_DIR 已存在，正在更新...${PLAIN}"
    cd "$INSTALL_DIR" && git pull
else
    echo -e "${GREEN}正在克隆 zsirdns 仓库到 $INSTALL_DIR...${PLAIN}"
    git clone https://github.com/dawangLM/zsirdns.git "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# 4. 下载内核
ARCH=$(uname -m)
OS="linux"

echo -e "${GREEN}正在检测系统架构: $ARCH...${PLAIN}"

# 根据架构映射文件名 (Clash Meta / Mihomo)
# 参考: https://github.com/MetaCubeX/mihomo/releases
case "$ARCH" in
    x86_64)
        CLASH_ARCH="amd64-compatible"
        MOSDNS_ARCH="amd64"
        ;;
    aarch64|arm64)
        CLASH_ARCH="arm64"
        MOSDNS_ARCH="arm64"
        ;;
    armv7*)
        CLASH_ARCH="armv7"
        MOSDNS_ARCH="arm-7"
        ;;
    *)
        echo -e "${RED}错误: 不支持的架构 $ARCH${PLAIN}"
        exit 1
        ;;
esac

# 下载 Clash (Mihomo)
echo -e "${GREEN}正在获取 Clash (Mihomo) 最新版本号...${PLAIN}"
CLASH_VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$CLASH_VERSION" ]; then
    echo -e "${RED}无法获取最新版本号，使用默认 v1.18.0${PLAIN}"
    CLASH_VERSION="v1.18.0"
fi

echo -e "${GREEN}正在下载 Clash (Mihomo) $CLASH_VERSION ($CLASH_ARCH) 内核...${PLAIN}"
CLASH_URL="https://github.com/MetaCubeX/mihomo/releases/download/${CLASH_VERSION}/mihomo-linux-${CLASH_ARCH}.gz"

wget -O clash.gz "$CLASH_URL"
gunzip -f clash.gz
chmod +x clash
mv clash /usr/local/bin/zsir-clash

# 下载 MosDNS
# 参考官方或第三方二进制包
echo -e "${GREEN}正在下载 MosDNS $MOSDNS_ARCH 内核...${PLAIN}"
# 使用更通用的下载源
MOSDNS_URL="https://github.com/IrfanAbid/mosdns-v5-binary/releases/latest/download/mosdns-linux-${MOSDNS_ARCH}.zip"

wget -O mosdns.zip "$MOSDNS_URL"
apt install -y unzip
unzip -o mosdns.zip
chmod +x mosdns
mv mosdns /usr/local/bin/zsir-mosdns
rm -f mosdns.zip

# 5. 配置服务
echo -e "${GREEN}正在配置 systemd 服务...${PLAIN}"

# Clash Service
cat <<EOF > /etc/systemd/system/zsir-clash.service
[Unit]
Description=zsirdns Clash Meta Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/local/bin/zsir-clash -f $INSTALL_DIR/config/clash.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# MosDNS Service
cat <<EOF > /etc/systemd/system/zsir-mosdns.service
[Unit]
Description=zsirdns MosDNS Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/local/bin/zsir-mosdns start -c $INSTALL_DIR/config/mosdns.yaml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zsir-clash zsir-mosdns
systemctl start zsir-clash zsir-mosdns

# 6. 设置旁路由转发
echo -e "${GREEN}正在执行旁路由配置脚本...${PLAIN}"
chmod +x setup_router.sh
bash setup_router.sh

echo -e "${BLUE}===============================================${PLAIN}"
echo -e "${GREEN}✅ zsirdns 安装并配置完成！${PLAIN}"
echo -e "${BLUE}网页仪表盘地址: http://$(curl -s ifconfig.me):8080 (需启动 monitor)${PLAIN}"
echo -e "${BLUE}MosDNS 状态: $(systemctl is-active zsir-mosdns)${PLAIN}"
echo -e "${BLUE}Clash 状态: $(systemctl is-active zsir-clash)${PLAIN}"
echo -e "${BLUE}===============================================${PLAIN}"
