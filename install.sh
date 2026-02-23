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

# 3. 确定安装目录与源码处理
# 优先使用脚本当前所在目录
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -d "$CURRENT_DIR/config" ] && [ -d "$CURRENT_DIR/ui" ]; then
    INSTALL_DIR="$CURRENT_DIR"
    echo -e "${BLUE}检测到当前已在项目目录 $INSTALL_DIR，跳过克隆...${PLAIN}"
else
    INSTALL_DIR="/etc/zsirdns"
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${BLUE}目录 $INSTALL_DIR 已存在，正在更新...${PLAIN}"
        cd "$INSTALL_DIR" && git pull
    else
        echo -e "${GREEN}正在克隆 zsirdns 仓库到 $INSTALL_DIR...${PLAIN}"
        git clone https://github.com/dawangLM/zsirdns.git "$INSTALL_DIR"
    fi
    cd "$INSTALL_DIR"
fi

# 创建 bin 目录用于存放内核，以便保持目录整洁
mkdir -p "$INSTALL_DIR/bin"
BIN_DIR="$INSTALL_DIR/bin"

# 4. 下载内核
ARCH_RAW=$(uname -m)
OS_RAW=$(uname -s | tr '[:upper:]' '[:lower:]')

echo -e "${GREEN}正在检测系统架构: $OS_RAW / $ARCH_RAW...${PLAIN}"

# 映射系统和架构名称
case "$OS_RAW" in
    linux) OS="linux" ;;
    darwin) OS="darwin" ;;
    *) echo -e "${RED}不支持的操作系统: $OS_RAW${PLAIN}"; exit 1 ;;
esac

case "$ARCH_RAW" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7*) ARCH="arm7" ;;
    *) echo -e "${RED}不支持的架构: $ARCH_RAW${PLAIN}"; exit 1 ;;
esac

# 对于 amd64 Linux，移除 compatible 后缀，直接使用标准版
CLASH_MATCH_STR="${OS}-${ARCH}"

# 下载 Clash (Mihomo)
echo -e "${GREEN}正在清理旧版本 Clash 并获取最新内核...${PLAIN}"
rm -f "$BIN_DIR/zsir-clash"

# 获取最新 release 的所有 asset 并进行匹配
CLASH_URL=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | \
    grep "browser_download_url" | grep "$CLASH_MATCH_STR" | grep ".gz" | head -n 1 | cut -d '"' -f 4)

if [ -z "$CLASH_URL" ]; then
    echo -e "${RED}错误: 无法在 GitHub Release 中找到适用于 $CLASH_MATCH_STR 的下载链接${PLAIN}"
    exit 1
fi

echo -e "${GREEN}找到内核链接: $(basename $CLASH_URL)${PLAIN}"
wget -O clash.gz "$CLASH_URL"
gunzip -f clash.gz
chmod +x clash
mv clash "$BIN_DIR/zsir-clash"

# 下载 MosDNS
echo -e "${GREEN}正在清理旧版本 MosDNS 并获取最新内核...${PLAIN}"
rm -f "$BIN_DIR/zsir-mosdns"

# 映射 MosDNS 架构名称
case "$ARCH_RAW" in
    x86_64) MOSDNS_ARCH="amd64" ;;
    aarch64|arm64) MOSDNS_ARCH="arm64" ;;
    armv7*) MOSDNS_ARCH="arm-7" ;;
esac

MOSDNS_URL="https://github.com/IrfanAbid/mosdns-v5-binary/releases/latest/download/mosdns-linux-${MOSDNS_ARCH}.zip"

wget -O mosdns.zip "$MOSDNS_URL"
apt install -y unzip
unzip -o mosdns.zip
chmod +x mosdns
mv mosdns "$BIN_DIR/zsir-mosdns"
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
ExecStart=$BIN_DIR/zsir-clash -f $INSTALL_DIR/config/clash.yaml
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
ExecStart=$BIN_DIR/zsir-mosdns start -c $INSTALL_DIR/config/mosdns.yaml
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
