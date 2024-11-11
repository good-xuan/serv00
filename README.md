！！！Run your own applications 需要开启

使用https://dashboard.uptimerobot.com/ 持续监控网页

使用https://github.com/hkfires/Keep-Serv00-Alive 脚本node保护进程  

步骤如下：  
wget -qO- https://raw.githubusercontent.com/good-xuan/serv00/refs/heads/main/01.xray.sh | bash   

wget  https://raw.githubusercontent.com/good-xuan/serv00/refs/heads/main/02.xray_conf.sh && bash 02.xray_conf.sh &&  rm 02.xray_conf.sh  

wget  https://raw.githubusercontent.com/good-xuan/serv00/refs/heads/main/03.node_conf.sh && bash 03.node_conf.sh &&  rm 03.node_conf.sh  

自动获取user,ws,user.serv00.net：   
wget -qO- https://raw.githubusercontent.com/good-xuan/serv00/refs/heads/main/03.node_conf_g.sh | bash 

弄乱了使用https://github.com/k0baya/X-for-serv00   重置  
bash <(curl -Ls https://raw.githubusercontent.com/k0baya/x-for-serv00/main/reset.sh)

安装sing-box使用https://github.com/frankiejun/serv00-play  
bash <(curl -Ls https://raw.githubusercontent.com/frankiejun/serv00-play/main/start.sh)


xray配置示例  
https://github.com/XTLS/Xray-examples  
https://github.com/chika0801/Xray-examples  
https://github.com/chika0801/sing-box-examples  
