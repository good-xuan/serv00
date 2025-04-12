#!/bin/bash

# 获取最新版本号
latest_version=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep "tag_name" | awk -F '"' '{print $4}')

# 如果没有获取到信息，设置默认值
if [ -z "$latest_version" ]; then
    latest_version="v25.3.6"
fi

# 下载
wget  https://github.com/XTLS/Xray-core/releases/download/${latest_version}/Xray-freebsd-64.zip

# 创建目标目录
mkdir -p ~/ws

unzip -o Xray-freebsd-64.zip -d ~/ws

# 删除除 `xray`和'config.*' 文件以外的所有文件
find ~/ws -type f ! -name "xray" ! -name "config.*" -delete

# 重命名 `xray` 为 `ws`
mv ~/ws/xray ~/ws/ws

# 清理下载的 zip 文件
rm Xray-freebsd-64.zip

echo "Xray-core 已下载、解压并重命名为 ~/ws/ws"
