#!/bin/bash

# 提示用户输入信息
read -p "请输入 Serv00 登录用户名: " user
read -p "请输入 pName (默认'ws'): " pName
read -p "请输入域名(默认'user.serv00.net'): " domain

if [ -z "$pName" ]; then
    pName="ws"
fi

if [ -z "$domain" ]; then
    domain="$user.serv00.net"
fi


mv /home/${user}/domains/${domain}/public_nodejs/public /home/${user}/domains/${domain}/public_nodejs/static


cat https://raw.incept.pw/good-xuan/serv00/main/node_t >>/home/${user}/domains/${domain}/public_nodejs/app.js

cat <<EOF > /home/${user}/domains/${domain}/public_nodejs/.env

user = "${user}"; 
pName = "${pName}"; 
domain = "${domain}";

EOF

echo "配置已输出到 /home/${user}/domains/${domain}/public_nodejs/app.js"
