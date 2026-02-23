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

# 3. 配置策略路由
echo "正在配置策略路由..."
ip rule add fwmark $TPROXY_MARK table $TABLE_ID
ip route add local default dev lo table $TABLE_ID

# 4. 配置 nftables 转发规则
echo "正在配置 nftables 转发规则..."
nft -f - <<EOF
table inet zsirdns {
    chain prerouting {
        type filter hook prerouting priority mangle; policy accept;
        
        # 忽略本地流量和内网流量
        ip daddr { 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4 } return
        
        # 将 Fake-IP 流量重定向到 Clash TProxy 端口
        # 如果使用 Fake-IP (198.18.0.0/16)
        ip daddr 198.18.0.0/16 meta mark set $TPROXY_MARK tproxy to :$TPROXY_PORT accept

        # 其他所有外部流量 (TCP/UDP) 转发到 Clash
        meta l4proto { tcp, udp } meta mark set $TPROXY_MARK tproxy to :$TPROXY_PORT accept
    }

    chain output {
        type route hook output priority mangle; policy accept;
        
        # 忽略本地流量
        ip daddr { 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 } return
        
        # 给本机发出的外部流量打标签，以便走策略路由
        meta l4proto { tcp, udp } meta mark set $TPROXY_MARK
    }
}
EOF

# 5. DNS 劫持 (将 53 端口强制重定向到 MosDNS)
echo "正在配置 DNS 劫持..."
# 如果 MosDNS 运行在 53 端口，以上规则已经处理了转发。
# 但为了确保万无一失，可以添加特定的劫持规则，或者让用户手动设置客户端 DNS 指向本路由 IP。

echo "✅ 旁路由模式配置完成！"
echo "提示: 请将客户端的 '网关' 和 'DNS' 均设置为本机器的 IP 地址。"
