#!/bin/bash

# 获取最新版本号
latest_version=$(curl -Ls https://data.jsdelivr.com/v1/package/gh/XTLS/Xray-core | grep -Eo '"[0-9.]+",' | sed -n 1p | tr -d '",')

# 如果没有获取到信息，设置默认值
if [ -z "$latest_version" ]; then
    latest_version="25.2.21"
fi

# 下载
cd /tmp
wget  https://github.com/XTLS/Xray-core/releases/download/v${latest_version}/Xray-linux-64.zip
unzip -o Xray-linux-64.zip -d /opt/xray



# 清理下载的 zip 文件
rm /tmp/Xray-linux-64.zip*

pm2 restart xray
#systemctl  restart  xray
echo "Xray-core 已下载并重启xray"
