#!/bin/bash

# 配置文件路径
config_path=~/ws/config.json

# 提示用户输入信息
read -p "请输入 VLESS 端口: " vless_port
read -p "请输入 VLESS 用户 UUID (留空生成随机 UUID): " uuid
read -p "请输入 Socks5 端口: " s5_port
read -p "请输入 Socks5 用户名: " s5_user
read -p "请输入 Socks5 密码: " s5_pass

# 如果 UUID 为空，则生成一个随机 UUID
if [[ -z "$uuid" ]]; then
    if command -v uuidgen >/dev/null 2>&1; then
        uuid=$(uuidgen)
    else
        # 如果系统没有 uuidgen，用另一种方式生成
        uuid=$(cat /proc/sys/kernel/random/uuid)
    fi
    echo "生成的随机 UUID: $uuid"
fi

# 创建配置文件内容
cat <<EOF > $config_path
{
    "log": {
        "loglevel": "warning"
    },
    "routing": {
        "rules": [
            {
                "port": "443",
                "network": "udp",
                "outboundTag": "block"
            }
        ]
    },
    "inbounds": [
        {
            "listen": "0.0.0.0",
            "port": $vless_port,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/"
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ]
            }
        },
        {
            "port": $s5_port,
            "protocol": "socks",
            "tag": "socks",
            "settings": {
                "auth": "password",
                "accounts": [
                    {
                        "user": "$s5_user",
                        "pass": "$s5_pass"
                    }
                ]
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}
EOF

echo "配置文件已生成在 $config_path"
