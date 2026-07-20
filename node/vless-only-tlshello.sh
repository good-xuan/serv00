#!/bin/sh

# ==============================================================================
#  0. 核心配置聚合
# ==============================================================================
PORT="${SERVER_PORT:-${PORT:-3000}}"
UUID="${UUID:-}"
LINK_NAME="${LINK_NAME:-Node}"
CDN_HOST="${CDN_HOST:-www.visa.com.sg}"
SERVER_IP="${SERVER_IP:-127.0.0.1}"
ENABLE_XRAY="${ENABLE_XRAY:-true}"
ENABLE_PQ="${ENABLE_PQ:-true}"
CUSTOM_DOMAIN="${CUSTOM_DOMAIN:-$CDN_HOST}"

BASE_DIR="$(pwd)"
PERSIST_FILE="$BASE_DIR/.sys_data"

FLOW=""
if [ "$ENABLE_PQ" != "false" ]; then
    FLOW="xtls-rprx-vision"
fi

# ==============================================================================
#  1. 动态环境与工具函数
# ==============================================================================
# 随机字符串生成工具
random_str() {
    cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 8 | head -n 1
}

TMP_DIR="$BASE_DIR/tmp"
BIN_FILE="$TMP_DIR/$(random_str)"
ZIP_FILE="$TMP_DIR/$(random_str).zip"
CFG_FILE="$TMP_DIR/config.json"
FILES_LINKS="$BASE_DIR/LINK.txt"

# 兼容 curl 和 wget 的下载器
download() {
    local url="$1"
    local dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -sL -o "$dest" -A "Mozilla/5.0 (Compatible; Alpine/sh)" "$url"
    else
        wget -q -O "$dest" -U "Mozilla/5.0 (Compatible; Alpine/sh)" "$url"
    fi
}

# ==============================================================================
#  2. 核心业务与执行主流程
# ==============================================================================
# 1. 清除旧的固定链接文件
rm -f "$FILES_LINKS"

# 2. 准备临时目录
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# 3. 加载/初始化持久化状态
if [ -z "$UUID" ] && [ -f "$PERSIST_FILE.uuid" ]; then
    UUID=$(cat "$PERSIST_FILE.uuid")
elif [ -z "$UUID" ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(random_str)-$(random_str)-$(random_str)-$(random_str)")
    echo "$UUID" > "$PERSIST_FILE.uuid"
fi

if [ -f "$PERSIST_FILE.paths" ]; then
    . "$PERSIST_FILE.paths"
else
    PATH_XHTTP="/$(random_str)"
    echo "PATH_XHTTP=\"$PATH_XHTTP\"" > "$PERSIST_FILE.paths"
fi
PATH_XHTTP="${XHTTP_PATH:-$PATH_XHTTP}"

# 辅助：生成链接 (仅限 xhttp)
generate_vless_link() {
    local host_arg="$1"
    local port_arg="$2"
    local remarks="$3"
    local is_domain="$4"

    local conn_host
    local conn_port
    local sni_val
    local net_type="xhttp"
    local path_val="$PATH_XHTTP"

    if [ "$is_domain" = "true" ]; then
        conn_host="$CDN_HOST"
        conn_port="443"
        sni_val="$host_arg"
    else
        conn_host="$host_arg"
        conn_port="$port_arg"
        sni_val="$CDN_HOST"
    fi

    local enc_param=""
    [ "$ENABLE_PQ" != "false" ] && [ -n "$PQ_ENC" ] && enc_param="&encryption=${PQ_ENC}"

    local flow_param=""
    [ -n "$FLOW" ] && flow_param="&flow=${FLOW}"

    local encoded_path=$(echo "$path_val" | awk '{gsub(/\//,"%2F"); print}')

    echo "vless://${UUID}@${conn_host}:${conn_port}?security=tls${enc_param}${flow_param}&sni=${sni_val}&fp=random&alpn=h2&type=${net_type}&path=${encoded_path}#${remarks}"
}

# 辅助：保存链接
save_link() {
    local content="$1"
    local title="$2"
    echo "" >> "$FILES_LINKS"
    echo "$title" >> "$FILES_LINKS"
    echo "$content" >> "$FILES_LINKS"
    echo "" >> "$FILES_LINKS"
}

# 4. Xray 核心流程
if [ "$ENABLE_XRAY" != "false" ]; then
    XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
    download "$XRAY_URL" "$ZIP_FILE"
    unzip -q -o "$ZIP_FILE" -d "$TMP_DIR"
    
    XRAY_EXTRACTED="$(find "$TMP_DIR" -type f -name "xray" | head -n 1)"
    mv "$XRAY_EXTRACTED" "$BIN_FILE"
    chmod 755 "$BIN_FILE"

    # 5. 证书生成与调用
    if [ ! -f "$PERSIST_FILE.cert.json" ]; then
        "$BIN_FILE" tls cert > "$PERSIST_FILE.cert.json"
    fi
    CERT_JSON_BLOCK=$(cat "$PERSIST_FILE.cert.json")

    # 6. PQ 密钥生成 (精确匹配 ML-KEM-768, Post-Quantum)
    PQ_DEC="$VLESS_DECRYPTION"
    PQ_ENC="$VLESS_ENCRYPTION"

    if [ "$ENABLE_PQ" != "false" ] && [ -z "$PQ_DEC" ]; then
        if [ -f "$PERSIST_FILE.pq" ]; then
            . "$PERSIST_FILE.pq"
        else
            "$BIN_FILE" vlessenc > "$TMP_DIR/pq_output.txt"
            PQ_DEC=$(awk -F'"' '/ML-KEM-768, Post-Quantum/{f=1} f && /"decryption":/{print $4; exit}' "$TMP_DIR/pq_output.txt")
            PQ_ENC=$(awk -F'"' '/ML-KEM-768, Post-Quantum/{f=1} f && /"encryption":/{print $4; exit}' "$TMP_DIR/pq_output.txt")
            
            echo "PQ_DEC=\"$PQ_DEC\"" > "$PERSIST_FILE.pq"
            echo "PQ_ENC=\"$PQ_ENC\"" >> "$PERSIST_FILE.pq"
        fi
    fi

    # 预处理 Decryption
    DECRYPTION_VAL="none"
    if [ "$ENABLE_PQ" != "false" ] && [ -n "$PQ_DEC" ]; then
        DECRYPTION_VAL="$PQ_DEC"
    fi

    # 构建 StreamSettings (仅 xhttp)
    STREAM_SETTINGS=$(cat <<EOF
{
    "sockopt": {"trustedXForwardedFor": ["CF-Connecting-IP","X-Real-IP"], "tcpcongestion": "bbr"},
    "network": "xhttp",
    "security": "tls",
    "tlsSettings": {
        "minVersion": "1.3",
        "certificates": [ $CERT_JSON_BLOCK ]
    },
    "xhttpSettings": { "path": "$PATH_XHTTP" }
}
EOF
)

    # 写入 config.json 最终配置
    cat <<EOF > "$CFG_FILE"
{
    "log": { "loglevel": "none" },
    "inbounds": [{
        "port": $PORT,
        "protocol": "vless",
        "settings": {
            "clients": [{ "id": "$UUID", "flow": "$FLOW" }],
            "decryption": "$DECRYPTION_VAL"
        },
        "streamSettings": $STREAM_SETTINGS
    }],
    "dns": { "servers": ["https+local://1.1.1.1/dns-query","localhost"] },
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct",
            "streamSettings": {
                "finalmask": {
                    "tcp": [{ "type": "fragment", "settings": {"packets":"tlshello","length":"100-200","delay":"10-20","maxSplit":"3-6"} }]
                },
                "sockopt": { "tcpcongestion": "bbr", "domainStrategy": "UseIP", "happyEyeballs": { "tryDelayMs": 250 } }
            }
        },
        { "protocol": "blackhole", "tag": "block" }
    ]
}
EOF

    # 守护进程拉起
    "$BIN_FILE" -c "$CFG_FILE" >/dev/null 2>&1 &
    XRAY_PID=$!

    # 7. 生成并保存链接
    if [ -n "$SERVER_IP" ]; then
        save_link "$(generate_vless_link "$SERVER_IP" "$PORT" "${LINK_NAME}-Direct" "false")" "Direct IP"
    fi
    if [ -n "$CUSTOM_DOMAIN" ]; then
        save_link "$(generate_vless_link "$CUSTOM_DOMAIN" "443" "${LINK_NAME}" "true")" "Custom Domain"
    fi
fi

echo "✅ Initialized Async Mode ( xhttp only)."
