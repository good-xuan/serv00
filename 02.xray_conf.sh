#!/bin/bash

# 配置文件路径
config_path=~/ws/config.json

# 提示用户输入信息
read -p "请输入 VLESS 端口: " vless_port
read -p "请输入 VLESS 用户 UUID (留空生成随机 UUID): " uuid


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
  "routing":
  {
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
      "port": "$vless_port",
      "protocol": "vless",
      "settings":
      {
        "clients": [
          {
            "id": "$uuid"
          }
        ],
        "decryption": "none"
      },
      "streamSettings":
      {
        "sockopt":
        {
          "tcpMptcp": true,
          "tcpNoDelay": true
        },
        "network": "ws",
        "security": "tls",
        "tlsSettings":
        {
          "alpn": [
            "http/1.1"
          ],
          "minVersion": "1.3",
          "certificates": [
            {
              "certificate": [
                "-----BEGIN CERTIFICATE-----",
                "MIIBgDCCASagAwIBAgIRAKKibtLxdvJrh+oY/G3B4GYwCgYIKoZIzj0EAwIwJjER",
                "MA8GA1UEChMIWHJheSBJbmMxETAPBgNVBAMTCFhyYXkgSW5jMB4XDTI0MTExMDA1",
                "MTkyOFoXDTI1MDIwODA2MTkyOFowJjERMA8GA1UEChMIWHJheSBJbmMxETAPBgNV",
                "BAMTCFhyYXkgSW5jMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEUZUR6KmqNSDE",
                "3eo4RUmDzQSK7MoWoHbriTtxlP3atJKbL78/eOf1jlK901EQcujzANSFi3X/b3KV",
                "ckcZVv5146M1MDMwDgYDVR0PAQH/BAQDAgWgMBMGA1UdJQQMMAoGCCsGAQUFBwMB",
                "MAwGA1UdEwEB/wQCMAAwCgYIKoZIzj0EAwIDSAAwRQIhAOg3ze6ngrwvhB0/wGBD",
                "5QbZFmuQtm8mEanIMCcx4LX3AiAlEa6odTfTEeUwWm23PF/xOP4jr8spKq9m+1aJ",
                "2VuE9A==",
                "-----END CERTIFICATE-----"
              ],
              "key": [
                "-----BEGIN RSA PRIVATE KEY-----",
                "MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgNeiiFrdxbipL3uIe",
                "ehNIKkVV8cD/9X1RRQKb0uSE/DmhRANCAARRlRHoqao1IMTd6jhFSYPNBIrsyhag",
                "duuJO3GU/dq0kpsvvz945/WOUr3TURBy6PMA1IWLdf9vcpVyRxlW/nXj",
                "-----END RSA PRIVATE KEY-----"
              ]
            }
          ]
        }
      },
      "sniffing":
      {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
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
