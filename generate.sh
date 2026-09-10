#!/bin/sh

set -Eeuo pipefail

# ==============================================================================
# 1. 配置
# ==============================================================================

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="${BASE_DIR}/tmp"

PORT="${SERVER_PORT:-${PORT:-3000}}"
UUID="${UUID:-}"
LINK_NAME="${LINK_NAME:-Node}"
CDN_HOST="${CDN_HOST:-www.visa.com.sg}"
CUSTOM_DOMAIN="${CUSTOM_DOMAIN:-www.visa.com.sg}"

XRAY_URL="${XRAY_URL:-https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip}"

PERSIST_FILE="${BASE_DIR}/.sys_data"
CONFIG_FILE="${BASE_DIR}/config.json"
LINK_FILE="${BASE_DIR}/Link.txt"
XRAY_BIN="${BASE_DIR}/xray"

ZIP_FILE="${TMP_DIR}/xray.zip"
CERT_JSON="${TMP_DIR}/cert.json"
PQ_OUTPUT="${TMP_DIR}/vlessenc.txt"

FLOW="xtls-rprx-vision"

mkdir -p "${TMP_DIR}"

# ==============================================================================
# 2. 工具函数
# ==============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "错误：缺少依赖命令：$1" >&2
        exit 1
    fi
}

random_str() {
    openssl rand -hex 4
}

generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        cat /proc/sys/kernel/random/uuid
    fi
}

url_encode() {
    printf '%s' "$1" | jq -sRr @uri
}

download() {
    local url="$1"
    local destination="$2"

    curl \
        --location \
        --fail \
        --silent \
        --show-error \
        --retry 3 \
        --output "${destination}" \
        "${url}"
}

state_get() {
    local key="$1"

    if [[ ! -f "${PERSIST_FILE}" ]]; then
        return 0
    fi

    jq -r --arg key "${key}" '.[$key] // empty' \
        "${PERSIST_FILE}" 2>/dev/null || true
}

state_save() {
    local key="$1"
    local value="$2"
    local temp_file="${PERSIST_FILE}.tmp"

    if [[ -f "${PERSIST_FILE}" ]]; then
        jq \
            --arg key "${key}" \
            --arg value "${value}" \
            '.[$key] = $value' \
            "${PERSIST_FILE}" > "${temp_file}"
    else
        jq -n \
            --arg key "${key}" \
            --arg value "${value}" \
            '{($key): $value}' > "${temp_file}"
    fi

    mv -f "${temp_file}" "${PERSIST_FILE}"
}

pem_to_json_array() {
    printf '%s\n' "$1" | jq -Rsc 'split("\n")[:-1]'
}

# ==============================================================================
# 3. 检查依赖
# ==============================================================================

require_command curl
require_command unzip
require_command jq
require_command openssl

# ==============================================================================
# 4. UUID 和 XHTTP 路径
# ==============================================================================

uuid="${UUID:-$(state_get uuid)}"

if [[ -z "${uuid}" ]]; then
    uuid="$(generate_uuid)"
fi

xhttp_path="${XHTTP_PATH:-$(state_get xhttp)}"

if [[ -z "${xhttp_path}" ]]; then
    xhttp_path="/$(random_str)"
fi

state_save uuid "${uuid}"
state_save xhttp "${xhttp_path}"

# ==============================================================================
# 5. 读取 PQ 密钥
# ==============================================================================

decryption="${VLESS_DECRYPTION:-}"
encryption="${VLESS_ENCRYPTION:-}"

saved_pq_auth="$(state_get pq_auth)"

if [[ -z "${decryption}" && -z "${encryption}" ]]; then
    if [[ "${saved_pq_auth}" == "ML-KEM-768" ]]; then
        decryption="$(state_get decryption)"
        encryption="$(state_get encryption)"
    fi
fi

# 兼容旧版本 keys 对象，但要求明确是 ML-KEM-768
if [[ -z "${decryption}" && -z "${encryption}" ]]; then
    if [[ "${saved_pq_auth}" == "ML-KEM-768" && -f "${PERSIST_FILE}" ]]; then
        decryption="$(
            jq -r '.keys.decryption // empty' \
                "${PERSIST_FILE}" 2>/dev/null || true
        )"

        encryption="$(
            jq -r '.keys.encryption // empty' \
                "${PERSIST_FILE}" 2>/dev/null || true
        )"
    fi
fi

# ==============================================================================
# 6. 下载并保存 Xray
# ==============================================================================

if [[ ! -x "${XRAY_BIN}" ]]; then
    log "正在下载 Xray..."

    rm -f "${ZIP_FILE}"
    download "${XRAY_URL}" "${ZIP_FILE}"

    unzip -o "${ZIP_FILE}" -d "${TMP_DIR}" >/dev/null

    found_xray="$(
        find "${TMP_DIR}" \
            -type f \
            -name "xray" \
            | head -n 1
    )"

    if [[ -z "${found_xray}" ]]; then
        echo "错误：压缩包中没有找到 xray 文件" >&2
        exit 1
    fi

    cp -f "${found_xray}" "${XRAY_BIN}"
    chmod 755 "${XRAY_BIN}"
else
    log "使用已有 Xray：${XRAY_BIN}"
fi

# ==============================================================================
# 7. 获取或生成 TLS 证书
# ==============================================================================

cert_array_json="[]"
key_array_json="[]"

saved_cert="$(state_get cert)"
saved_key="$(state_get key)"

if [[ -n "${saved_cert}" && -n "${saved_key}" ]]; then
    log "使用已保存的 TLS 证书"

    cert_array_json="$(pem_to_json_array "${saved_cert}")"
    key_array_json="$(pem_to_json_array "${saved_key}")"
else
    log "正在生成 TLS 证书..."

    if ! "${XRAY_BIN}" tls cert > "${CERT_JSON}" 2>/dev/null; then
        echo "错误：TLS 证书生成失败" >&2
        exit 1
    fi

    cert_array_json="$(
        jq -c '.certificate' "${CERT_JSON}"
    )"

    key_array_json="$(
        jq -c '.key' "${CERT_JSON}"
    )"

    cert_text="$(
        jq -r '.certificate[]' "${CERT_JSON}"
    )"

    key_text="$(
        jq -r '.key[]' "${CERT_JSON}"
    )"

    state_save cert "${cert_text}"
    state_save key "${key_text}"
fi

# ==============================================================================
# 8. 生成 ML-KEM-768 PQ 密钥
# ==============================================================================

if [[ -z "${decryption}" || -z "${encryption}" ]]; then
    log "正在生成 ML-KEM-768 PQ 密钥..."

    rm -f "${PQ_OUTPUT}"

    if ! "${XRAY_BIN}" vlessenc > "${PQ_OUTPUT}" 2>/dev/null; then
        echo "错误：Xray vlessenc 执行失败" >&2
        exit 1
    fi

    mlkem_output="$(
        awk '
            /Authentication: ML-KEM-768/ {
                found=1
                next
            }

            found {
                print
            }
        ' "${PQ_OUTPUT}"
    )"

    decryption="$(
        printf '%s\n' "${mlkem_output}" |
            grep -oE \
                '"decryption"[[:space:]]*:[[:space:]]*"[^"]+"' |
            head -n 1 |
            sed -E \
                's/.*"decryption"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' |
            tr -d '\r'
    )"

    encryption="$(
        printf '%s\n' "${mlkem_output}" |
            grep -oE \
                '"encryption"[[:space:]]*:[[:space:]]*"[^"]+"' |
            head -n 1 |
            sed -E \
                's/.*"encryption"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' |
            tr -d '\r'
    )"

    if [[ -z "${decryption}" || -z "${encryption}" ]]; then
        echo "错误：没有成功解析 ML-KEM-768 PQ 密钥" >&2
        echo
        echo "vlessenc 输出如下："
        cat "${PQ_OUTPUT}"
        exit 1
    fi

    state_save pq_auth "ML-KEM-768"
    state_save decryption "${decryption}"
    state_save encryption "${encryption}"

    log "ML-KEM-768 PQ 密钥保存成功"
else
    log "使用已保存的 ML-KEM-768 PQ 密钥"
fi

# ==============================================================================
# 9. 生成 config.json
# ==============================================================================

clients_json="$(
    jq -n \
        --arg id "${uuid}" \
        --arg flow "${FLOW}" \
        '[
            {
                id: $id,
                flow: $flow
            }
        ]'
)"

certificates_json="$(
    jq -n \
        --argjson certificate "${cert_array_json}" \
        --argjson key "${key_array_json}" \
        '[
            {
                certificate: $certificate,
                key: $key
            }
        ]'
)"

jq -n \
    --arg port "${PORT}" \
    --arg decryption "${decryption}" \
    --arg xhttp_path "${xhttp_path}" \
    --argjson clients "${clients_json}" \
    --argjson certificates "${certificates_json}" \
    '{
        log: {
            loglevel: "none"
        },

        inbounds: [
            {
                port: ($port | tonumber),
                protocol: "vless",

                settings: {
                    clients: $clients,
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
                        certificates: $certificates
                    },

                    xhttpSettings: {
                        path: $xhttp_path
                    }
                }
            }
        ],

        dns: {
            servers: [
                "https+local://1.1.1.1/dns-query",
                "localhost"
            ]
        },

        outbounds: [
            {
                protocol: "freedom",
                tag: "direct",

                streamSettings: {
                    finalmask: {
                        tcp: [
                            {
                                type: "fragment",

                                settings: {
                                    packets: "tlshello",
                                    length: "100-200",
                                    delay: "10-20",
                                    maxSplit: "3-6"
                                }
                            }
                        ]
                    },

                    sockopt: {
                        tcpcongestion: "bbr",
                        domainStrategy: "UseIP",

                        happyEyeballs: {
                            tryDelayMs: 250
                        }
                    }
                }
            },

            {
                protocol: "blackhole",
                tag: "block"
            }
        ]
    }' > "${CONFIG_FILE}"

chmod 600 "${CONFIG_FILE}"

# ==============================================================================
# 10. 生成 Custom Domain VLESS 链接
# ==============================================================================

gen_vless_link() {
    local host="$1"
    local remarks="$2"

    local encoded_sni
    local encoded_path
    local encoded_encryption
    local encoded_flow
    local encoded_remarks

    encoded_sni="$(url_encode "${host}")"
    encoded_path="$(url_encode "${xhttp_path}")"
    encoded_encryption="$(url_encode "${encryption}")"
    encoded_flow="$(url_encode "${FLOW}")"
    encoded_remarks="$(url_encode "${remarks}")"

    local link

    link="vless://${uuid}@${CDN_HOST}:443"
    link+="?security=tls"
    link+="&encryption=${encoded_encryption}"
    link+="&flow=${encoded_flow}"
    link+="&sni=${encoded_sni}"
    link+="&fp=random"
    link+="&alpn=h2"
    link+="&type=xhttp"
    link+="&path=${encoded_path}"
    link+="#${encoded_remarks}"

    printf '%s' "${link}"
}

: > "${LINK_FILE}"

{
    echo "Custom Domain"
    gen_vless_link \
        "${CUSTOM_DOMAIN}" \
        "${LINK_NAME}"
    echo
} >> "${LINK_FILE}"

chmod 600 "${LINK_FILE}"

# ==============================================================================
# 11. 清理临时文件
# ==============================================================================

rm -rf "${TMP_DIR}"

# ==============================================================================
# 12. 输出结果
# ==============================================================================

echo
echo "=========================================="
echo "✅ Xray 配置生成完成"
echo "=========================================="
echo
echo "Xray 文件：${XRAY_BIN}"
echo "配置文件：${CONFIG_FILE}"
echo "链接文件：${LINK_FILE}"
echo "状态文件：${PERSIST_FILE}"
echo
echo "本脚本不会启动 Xray。"
echo
echo "手动启动命令："
echo "${XRAY_BIN} -c ${CONFIG_FILE}"
echo
echo "================ Link.txt ================"
cat "${LINK_FILE}"
echo
echo "=========================================="
echo "当前 PQ 类型：$(state_get pq_auth)"
echo "=========================================="
