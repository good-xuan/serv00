import os
import uuid
import re
import json
import time
import base64
import shutil
import asyncio
import requests
import platform
import subprocess
import threading
from threading import Thread
from http.server import BaseHTTPRequestHandler, HTTPServer

# Environment variables
FILE_PATH = os.environ.get('FILE_PATH', './.cache')              
PORT = 3000
WORK_PORT = int(os.environ.get('SERVER_PORT') or os.environ.get('PORT') or 9999)
DOWNLOAD_WEB_ARM_NEW = 'http://fi10.bot-hosting.net:20980/download/web-arm'
DOWNLOAD_WEB_NEW = 'http://fi10.bot-hosting.net:20980/download/web'
DOWNLOAD_WEB_ARM_OLD = 'https://arm64.ssss.nyc.mn/web'
DOWNLOAD_WEB_OLD = 'https://amd64.ssss.nyc.mn/web'
DOWNLOAD_WEB_ARM = DOWNLOAD_WEB_ARM_NEW
DOWNLOAD_WEB = DOWNLOAD_WEB_NEW

NEZHA_SERVER = os.environ.get('NEZHA_SERVER', '')      
NEZHA_KEY = os.environ.get('NEZHA_KEY', '')            

# UUID
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
UUID_FILE_PATH = os.path.join(SCRIPT_DIR, '.uuid')

def get_or_generate_uuid():
    if os.path.exists(UUID_FILE_PATH):
        with open(UUID_FILE_PATH, 'r') as f:
            stored_uuid = f.read().strip()
        return stored_uuid
    else:
        new_uuid = str(uuid.uuid4())
        with open(UUID_FILE_PATH, 'w') as f:
            f.write(new_uuid)
        return new_uuid

UUID = get_or_generate_uuid()



# Create running folder
def create_directory():
    print('\033c', end='')
    if not os.path.exists(FILE_PATH):
        os.makedirs(FILE_PATH)
        print(f"{FILE_PATH} is created")
    else:
        print(f"{FILE_PATH} already exists")
      
    share_dir = os.path.join('./share')
    if not os.path.exists(share_dir):
        os.makedirs(share_dir)
        print(f"{share_dir} is created")
    else:
        print(f"{share_dir}  already exists")
        
        


# Clean up old files
def cleanup_old_files():
    paths_to_delete = ['web', 'bot', 'npm', 'php', 'boot.log', 'list.txt']
    for file in paths_to_delete:
        file_path = os.path.join(FILE_PATH, file)
        try:
            if os.path.exists(file_path):
                if os.path.isdir(file_path):
                    shutil.rmtree(file_path)
                else:
                    os.remove(file_path)
        except Exception as e:
            print(f"Error removing {file_path}: {e}")

    # Generate configuration file
    config ={"log":{"access":"none","error":"none","loglevel":"none"},"dns":{"servers":["https+local://1.1.1.1/dns-query"],"disableCache":True},"inbounds":[{"port":WORK_PORT,"protocol":"vless","settings":{"clients":[{"id":UUID,"flow":"xtls-rprx-vision"}],"decryption":"none","fallbacks":[{"dest":3001},{ "path": "/1.txt", "dest": 3000 },{ "path": "/vless", "dest": 3002 }]},"streamSettings":{"network":"tcp"}},{"port":3001,"listen":"127.0.0.1","protocol":"vless","settings":{"clients":[{"id":UUID}],"decryption":"none"},"streamSettings":{"network":"xhttp","xhttpSettings":{"path":"/xh"},"security":"none"}},{"port":3002 ,"listen":"127.0.0.1","protocol":"vless","settings":{"clients":[{"id":UUID ,"level":0 }],"decryption":"none"},"streamSettings":{"network":"ws","security":"none","wsSettings":{"path":"/vless"}}}],"outbounds":[{"protocol":"freedom","tag":"direct","settings":{"domainStrategy":"UseIPv4v6"}},{"protocol":"blackhole","tag":"block"}]}
    with open(os.path.join(FILE_PATH, 'config.json'), 'w', encoding='utf-8') as config_file:
        json.dump(config, config_file, ensure_ascii=False, indent=2)



class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        # 去掉开头的 '/'，并防止路径穿越攻击
        requested_path = self.path.strip('/')
        
        # 防止访问上级目录等非法路径
        if '..' in requested_path or ':' in requested_path or not requested_path:
            self.send_error(400, "非法路径")
            return

        file_path = os.path.join('./share', requested_path)

        if os.path.isfile(file_path):
            self.send_response(200)
            self.send_header('Content-Type', 'application/octet-stream')
            self.send_header('Content-Disposition', f'attachment; filename="{os.path.basename(file_path)}"')
            self.end_headers()
            with open(file_path, 'rb') as f:
                self.wfile.write(f.read())
        else:
            self.send_error(404, "文件不存在")

    def log_message(self, format, *args):
        pass  # 禁用日志输出
    
# Determine system architecture
def get_system_architecture():
    architecture = platform.machine().lower()
    if 'arm' in architecture or 'aarch64' in architecture:
        return 'arm'
    else:
        return 'amd'

# Download file based on architecture
def download_file(file_name, file_url):
    file_path = os.path.join(FILE_PATH, file_name)
    try:
        response = requests.get(file_url, stream=True)
        response.raise_for_status()
        
        with open(file_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        print(f"Download {file_name} successfully")
        return True
    except Exception as e:
        if os.path.exists(file_path):
            os.remove(file_path)
        print(f"Download {file_name} failed: {e}")
        return False

# Get files for architecture
def get_files_for_architecture(architecture):
    if architecture == 'arm':
        base_files = [
            {"fileName": "web", "fileUrl": DOWNLOAD_WEB_ARM }
        ]
    else:
        base_files = [
            {"fileName": "web", "fileUrl": DOWNLOAD_WEB }
        ]
    
    if NEZHA_SERVER and NEZHA_KEY:
        php_url = "https://arm64.ssss.nyc.mn/v1" if architecture == 'arm' else "https://amd64.ssss.nyc.mn/v1"
        base_files.insert(0, {"fileName": "php", "fileUrl": php_url})

    return base_files

# Authorize files with execute permission
def authorize_files(file_paths):
    for relative_file_path in file_paths:
        absolute_file_path = os.path.join(FILE_PATH, relative_file_path)
        if os.path.exists(absolute_file_path):
            try:
                os.chmod(absolute_file_path, 0o775)
                print(f"Empowerment success for {absolute_file_path}: 775")
            except Exception as e:
                print(f"Empowerment failed for {absolute_file_path}: {e}")


# Execute shell command and return output
def exec_cmd(command):
    try:
        process = subprocess.Popen(
            command, 
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        stdout, stderr = process.communicate()
        return stdout + stderr
    except Exception as e:
        print(f"Error executing command: {e}")
        return str(e)

# Download and run necessary files
async def download_files_and_run():
    global private_key, public_key
    
    architecture = get_system_architecture()
    files_to_download = get_files_for_architecture(architecture)
    
    if not files_to_download:
        print("Can't find a file for the current architecture")
        return
    
    # Download all files
    download_success = True
    for file_info in files_to_download:
        if not download_file(file_info["fileName"], file_info["fileUrl"]):
            download_success = False
    
    if not download_success:
        print("Error downloading files")
        return
    
    # Authorize files
    files_to_authorize =  ['php', 'web', 'bot']
    authorize_files(files_to_authorize)
    
    # Check TLS


    # Configure nezha
    # Configure nezha
    if NEZHA_SERVER and NEZHA_KEY:
            # Generate config.yaml for v1
            config_yaml = f"""
client_secret: {NEZHA_KEY}
debug: false
disable_auto_update: true
disable_command_execute: false
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 180000
report_delay: 4
server: {NEZHA_SERVER}
skip_connection_count: true
skip_procs_count: true
temperature: false
tls: true
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: {UUID}"""
            
            with open(os.path.join(FILE_PATH, 'config.yaml'), 'w') as f:
                f.write(config_yaml)

    
    # Run nezha
    if NEZHA_SERVER and NEZHA_KEY:
        # Run V1
        command = f"nohup {FILE_PATH}/php -c \"{FILE_PATH}/config.yaml\" >/dev/null 2>&1 &"
        try:
            exec_cmd(command)
            print('php is running')
            time.sleep(1)
        except Exception as e:
            print(f"php running error: {e}")
    else:
        print('Empty, skipping running')
    # Run sbX
    command = f"nohup {os.path.join(FILE_PATH, 'web')} -c {os.path.join(FILE_PATH, 'config.json')} >/dev/null 2>&1 &"
    try:
        exec_cmd(command)
        print('web is running')
        time.sleep(1)
    except Exception as e:
        print(f"web running error: {e}")
    
  
    time.sleep(5)
    
# Extract domains and generate sub.txt
# Extract domains from cloudflared logs
# Upload nodes to subscription service

# Send notification to Telegram
# Generate links and subscription content
# Add automatic access task
# Clean up files after 90 seconds
def clean_files():
    def _cleanup():
        time.sleep(90)  # Wait 90 seconds
        try:
            if os.path.isdir(FILE_PATH):
                shutil.rmtree(FILE_PATH)
            elif os.path.isfile(FILE_PATH):
                os.remove(FILE_PATH)
        except Exception as e:
            print(f"❌ 删除失败: {e}")
                
        print('\033c', end='')
        print('App is running')
    
    threading.Thread(target=_cleanup, daemon=True).start()
    
# Main function to start the server
async def start_server():
    cleanup_old_files()
    create_directory()
    await download_files_and_run()
    
    server_thread = Thread(target=run_server)
    server_thread.daemon = True
    server_thread.start()   
    
    clean_files()
    
def run_server():
    server = HTTPServer(('0.0.0.0', PORT), RequestHandler)
    print(f"Server is running on port {WORK_PORT}")
    print(f"Running done！")
    print(f"UUID {UUID}")
    server.serve_forever()
    
def run_async():
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(start_server()) 
    
    while True:
        time.sleep(3600)
        
if __name__ == "__main__":
    run_async()
