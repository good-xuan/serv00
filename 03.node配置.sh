#!/bin/bash

# 提示用户输入信息
read -p "请输入 Serv00 登录用户名: " user
read -p "请输入 pName (例如 's5'): " pName
read -p "请输入域名: " domain


const domain = "${domain}"; // 用户输入的域名

mv /home/${user}/domains/${domain}/public_nodejs/public /home/${user}/domains/${domain}/public_nodejs/static

cat <<EOF > /home/${user}/domains/${domain}/public_nodejs/app.js

const express = require("express");
const path = require("path");
const exec = require("child_process").exec;
const app = express();
const port = 3000;

const user = "${user}"; // 用户输入的用户名
const pName = "${pName}"; // 用户输入的 pName

app.use(express.static(path.join(__dirname, 'static')));

function keepWebAlive() {
  const currentDate = new Date();
  const formattedDate = currentDate.toLocaleDateString();
  const formattedTime = currentDate.toLocaleTimeString();

  exec(`pgrep -laf ${pName}`, (err, stdout) => {
    const Process = `/home/${user}/${pName}/${pName} -c /home/${user}/${pName}/config.json`;

    if (stdout.includes(Process)) {
      console.log(`${formattedDate}, ${formattedTime}: Web Running`);
    } else {
      exec(`nohup ${Process} >/dev/null 2>&1 &`, (err) => {
        if (err) {
          console.log(`${formattedDate}, ${formattedTime}: Keep alive error: ${err}`);
        } else {
          console.log(`${formattedDate}, ${formattedTime}: Keep alive success!`);
        }
      });
    }
  });
}

setInterval(keepWebAlive, 10 * 1000);

app.listen(port, () => {
  console.log(`Server is listening on port ${port}!`);
});

EOF

echo "配置已输出到 /home/${user}/domains/${domain}/public_nodejs/app.js"
