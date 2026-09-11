#!/bin/sh
set -e

BASE_DIR="$(pwd)"
TMP_DIR="${BASE_DIR}/tmp"
STATE_FILE="${BASE_DIR}/.sys_data"
CONFIG_FILE="${TMP_DIR}/config.json"

rm -rf "$TMP_DIR" && mkdir -p "$TMP_DIR"
[ -f "$STATE_FILE" ] || echo '{}' > "$STATE_FILE"

# 1. 基础参数与 UUID / Path 读取
PORT="${SERVER_PORT:-${PORT:-3000}}"
FLOW="xtls-rprx-vision"
CDN_HOST="${CDN_HOST:-www.visa.com.sg}"
CUSTOM_DOMAIN="${CUSTOM_DOMAIN:-www.visa.com.sg}"
LINK_NAME="${LINK_NAME:-Node}"

UUID="${UUID:-$(jq -r '.uuid // empty' "$STATE_FILE")}"
[ -z "$UUID" ] && UUID="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}')"

XHTTP_PATH="${XHTTP_PATH:-$(jq -r '.xhttp // empty' "$STATE_FILE")}"
[ -z "$XHTTP_PATH" ] && XHTTP_PATH="/$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"

# 2. 下载 Xray
wget -qO "${TMP_DIR}/x.zip" "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
unzip -oq "${TMP_DIR}/x.zip" -d "$TMP_DIR"
chmod 755 "${TMP_DIR}/xray"

# 3. 读取或生成 ML-KEM-768 密钥
DECRYPTION="${VLESS_DECRYPTION:-$(jq -r '.decryption // empty' "$STATE_FILE")}"
ENCRYPTION="${VLESS_ENCRYPTION:-$(jq -r '.encryption // empty' "$STATE_FILE")}"

if [ -z "$DECRYPTION" ] || [ -z "$ENCRYPTION" ]; then
    "${TMP_DIR}/xray" vlessenc > "${TMP_DIR}/enc.txt" 2>&1 || true
    DECRYPTION=$(awk '/Authentication:[[:space:]]*ML-KEM-768/{flag=1;next}/^Authentication:/{flag=0}flag && /"decryption"/{gsub(/.*:[[:space:]]*"|"[[:space:]]*,?/,"");print;exit}' "${TMP_DIR}/enc.txt")
    ENCRYPTION=$(awk '/Authentication:[[:space:]]*ML-KEM-768/{flag=1;next}/^Authentication:/{flag=0}flag && /"encryption"/{gsub(/.*:[[:space:]]*"|"[[:space:]]*,?/,"");print;exit}' "${TMP_DIR}/enc.txt")
fi

# 4. 读取或生成 TLS 证书 JSON 对象并存入 .sys_data
TLS_CERT_JSON="$(jq -c '.tls_cert // empty' "$STATE_FILE")"

if [ -z "$TLS_CERT_JSON" ]; then
    # 直接由 xray 输出 JSON 格式证书
    TLS_CERT_JSON="$("${TMP_DIR}/xray" tls cert -domain "$CUSTOM_DOMAIN")"
fi

# 持久化所有参数及证书 JSON 到 .sys_data
jq --arg u "$UUID" \
   --arg p "$XHTTP_PATH" \
   --arg dec "$DECRYPTION" \
   --arg enc "$ENCRYPTION" \
   --argjson cert "$TLS_CERT_JSON" \
   '.uuid = $u | .xhttp = $p | .decryption = $dec | .encryption = $enc | .tls_cert = $cert' \
   "$STATE_FILE" > "${STATE_FILE}.tmp"
mv -f "${STATE_FILE}.tmp" "$STATE_FILE"

# 5. 生成单入站 TLS 配置
jq -n \
    --argjson port "$PORT" \
    --argjson cert "$TLS_CERT_JSON" \
    --arg uuid "$UUID" \
    --arg flow "$FLOW" \
    --arg xhttp_path "$XHTTP_PATH" \
    --arg decryption "$DECRYPTION" \
    '{
        log: { loglevel: "none" },
        inbounds: [
            {
                port: $port,
                protocol: "vless",
                settings: {
                    clients: [{ id: $uuid, flow: $flow }],
                    decryption: $decryption
                },
                streamSettings: {
                    sockopt: {
                        trustedXForwardedFor: [
                            "CF-Connecting-IP",
                            "X-Real-IP"
                        ],
                        tcpcongestion: "bbr"
                    },
                    network: "xhttp",
                    security: "tls",
                    tlsSettings: {
                        minVersion: "1.3",
                        certificates: [$cert]
                    },
                    xhttpSettings: {
                        path: $xhttp_path
                    }
                }
            }
        ],
        dns: {
            servers: ["https+local://1.1.1.1/dns-query", "localhost"]
        },
        outbounds: [
            {
                protocol: "freedom",
                tag: "direct",
                streamSettings: {
                    finalmask: {
                        tcp: [{
                            type: "fragment",
                            settings: {
                                packets: "tlshello",
                                length: "100-200",
                                delay: "10-20",
                                maxSplit: "3-6"
                            }
                        }]
                    },
                    sockopt: {
                        tcpcongestion: "bbr",
                        domainStrategy: "UseIP",
                        happyEyeballs: { tryDelayMs: 250 }
                    }
                }
            },
            { protocol: "blackhole", tag: "block" }
        ]
    }' > "$CONFIG_FILE"

# 6. 打印链接并启动
ENCODED_DOMAIN=$(printf '%s' "$CUSTOM_DOMAIN" | jq -sRr @uri)
ENCODED_PATH=$(printf '%s' "$XHTTP_PATH" | jq -sRr @uri)
ENCODED_ENCRYPTION=$(printf '%s' "$ENCRYPTION" | jq -sRr @uri)
ENCODED_FLOW=$(printf '%s' "$FLOW" | jq -sRr @uri)
ENCODED_REMARK=$(printf '%s' "$LINK_NAME" | jq -sRr @uri)

echo ""
echo "============== Custom Domain =============="
echo "vless://${UUID}@${CDN_HOST}:443?security=tls&encryption=${ENCODED_ENCRYPTION}&flow=${ENCODED_FLOW}&sni=${ENCODED_DOMAIN}&fp=random&alpn=h2&type=xhttp&path=${ENCODED_PATH}#${ENCODED_REMARK}"
echo "============================================"
echo ""

exec "${TMP_DIR}/xray" run -c "$CONFIG_FILE"
