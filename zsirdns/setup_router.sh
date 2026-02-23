#!/bin/bash

# zsirdns 旁路由(透明网关)设置脚本
# 适用环境: Debian/Ubuntu (使用 nftables)

# 1. 基础配置
TPROXY_PORT=7893
TPROXY_MARK=0x1
TABLE_ID=100

# 2. 开启内核转发
echo "正在开启内核转发..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.forwarding=1
sysctl -w net.ipv6.conf.all.forwarding=1

# 3. 配置 nftables 转发规则 (可选，TUN 模式 auto-route 已处理大部分)
# 但对于旁路由，我们需要确保进入本机的非本地流量能正确进入网络栈处理
echo "正在配置基础转发规则..."
nft -f - <<EOF
table inet zsirdns {
    chain forward {
        type filter hook forward priority 0; policy accept;
    }
}
EOF

# 4. DNS 劫持说明
# 由于 MosDNS 监听在 53 端口，客户端将 DNS 指向本机即可。
# Clash TUN 的 dns-hijack 也会作为一个补充。

echo "✅ 旁路由(TUN模式)基础配置完成！"
echo "提示: 请将客户端的 '网关' 和 'DNS' 均设置为本机器的 IP 地址。"
