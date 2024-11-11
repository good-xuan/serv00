#!/bin/bash
current_dir=$(pwd)
user=$(echo "$current_dir" | awk -F'/' '{print $3}')

if [ -z "$pName" ]; then
    pName="ws"
fi

if [ -z "$domain" ]; then
    domain="$user.serv00.net"
fi


mv /home/${user}/domains/${domain}/public_nodejs/public /home/${user}/domains/${domain}/public_nodejs/static

cd /home/${user}/domains/${domain}/public_nodejs/
npm22 install express

rm /home/${user}/domains/${domain}/public_nodejs/app.js
rm /home/${user}/domains/${domain}/public_nodejs/config.js

wget -O /home/${user}/domains/${domain}/public_nodejs/app.js https://raw.githubusercontent.com/good-xuan/serv00/refs/heads/main/node_j

cat <<EOF > /home/${user}/domains/${domain}/public_nodejs/config.js

const user = "${user}"; 
const pName = "${pName}"; 
const domain = "${domain}";
module.exports = { user, pName, domain };
EOF

echo "配置已输出到 /home/${user}/domains/${domain}/public_nodejs/app.js"

wget -P /home/${user}/domains/${domain}/public_nodejs/static https://github.com/good-xuan/serv00/raw/refs/heads/main/html.zip 
unzip -o /home/${user}/domains/${domain}/public_nodejs/static/html.zip -P /home/${user}/domains/${domain}/public_nodejs/static/ 
rm /home/${user}/domains/${domain}/public_nodejs/static/html.zip
