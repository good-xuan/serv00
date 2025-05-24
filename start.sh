#!/bin/bash
#进如脚本所在目录
cd "$(dirname "$0")"
#后台运行函数
houTai(){
    nohup $@ >/dev/null 2>&1 &
}

#执行函数,后台运行
houTai ./xray run -c config.json
