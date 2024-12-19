#!/bin/bash

# 获取最新版本号
latest_version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep "tag_name" | awk -F '"' '{print $4}')

# 如果没有获取到信息，设置默认值
if [ -z "$latest_version" ]; then
    latest_version="v24.12.18"
fi

# 下载
cd /tmp
wget  https://github.com/XTLS/Xray-core/releases/download/${latest_version}/Xray-linux-64.zip

# 创建目标目录


unzip -o Xray-linux-64.zip -d /opt/xray



# 清理下载的 zip 文件
rm /tmp/Xray-linux-64.zip

systemctl  restart  xray
echo "Xray-core 已下载并重启xray"
