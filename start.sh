#!/bin/bash
cd "$(dirname "$0")"
houTai(){
    nohup $@ >/dev/null 2>&1 &
}

houTai ./xray run -c config.json
