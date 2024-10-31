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

rm /home/${user}/domains/${domain}/public_nodejs/app.js
rm /home/${user}/domains/${domain}/public_nodejs/config.js

wget -O /home/${user}/domains/${domain}/public_nodejs/app.js https://raw.githubusercontent.com/good-xuan/serv00/refs/heads/main/node_t

cat <<EOF > /home/${user}/domains/${domain}/public_nodejs/config.js

const user = "${user}"; 
const pName = "${pName}"; 
const domain = "${domain}";
module.exports = { user, pName, domain };
EOF

echo "配置已输出到 /home/${user}/domains/${domain}/public_nodejs/app.js"
