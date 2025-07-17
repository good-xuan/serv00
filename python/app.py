import os
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
SUB_PATH = os.environ.get('SUB_PATH', 'sub')           
UUID = os.environ.get('UUID', '20e6e496-cf19-45c8-b883-14f5e11cd9f1')  
PORT = int(3000)   
ARGO_PORT = int(os.environ.get('SERVER_PORT') or os.environ.get('PORT') or 9999)

# Create running folder
def create_directory():
    print('\033c', end='')
    if not os.path.exists(FILE_PATH):
        os.makedirs(FILE_PATH)
        print(f"{FILE_PATH} is created")
    else:
        print(f"{FILE_PATH} already exists")

# Global variables
npm_path = os.path.join(FILE_PATH, 'npm')
php_path = os.path.join(FILE_PATH, 'php')
web_path = os.path.join(FILE_PATH, 'web')
bot_path = os.path.join(FILE_PATH, 'bot')
sub_path = os.path.join(FILE_PATH, 'sub.txt')
list_path = os.path.join(FILE_PATH, 'list.txt')
boot_log_path = os.path.join(FILE_PATH, 'boot.log')
config_path = os.path.join(FILE_PATH, 'config.json')


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

class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'Hello World')
            
        elif self.path == f'/{SUB_PATH}':
            try:
                with open(sub_path, 'rb') as f:
                    content = f.read()
                self.send_response(200)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(content)
            except:
                self.send_response(404)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass
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


    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'Hello World')
            
        elif self.path == f'/{SUB_PATH}':
            try:
                with open(sub_path, 'rb') as f:
                    content = f.read()
                self.send_response(200)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(content)
            except:
                self.send_response(404)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass
    
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
            {"fileName": "web", "fileUrl": "https://arm64.ssss.nyc.mn/web"}
        ]
    else:
        base_files = [
            {"fileName": "web", "fileUrl": "https://amd64.ssss.nyc.mn/web"}
        ]


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

    # Generate configuration file
    config ={"log":{"access":"none","error":"none","loglevel":"none"},"dns":{"servers":["https+local://1.1.1.1/dns-query"],"disableCache":True},"inbounds":[{"port":ARGO_PORT,"protocol":"vless","settings":{"clients":[{"id":UUID,"flow":"xtls-rprx-vision"}],"decryption":"none","fallbacks":[{"dest":3001}]},"streamSettings":{"network":"tcp"}},{"port":3001,"listen":"127.0.0.1","protocol":"vless","settings":{"clients":[{"id":UUID}],"decryption":"none"},"streamSettings":{"network":"xhttp","xhttpSettings":{"path":"/xh"},"security":"none"}}],"outbounds":[{"protocol":"freedom","tag":"direct","settings":{"domainStrategy":"UseIPv4v6"}},{"protocol":"blackhole","tag":"block"}]}
    with open(os.path.join(FILE_PATH, 'config.json'), 'w', encoding='utf-8') as config_file:
        json.dump(config, config_file, ensure_ascii=False, indent=2)
    
    # Run nezha

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
        files_to_delete = [boot_log_path, config_path, list_path, web_path, bot_path, php_path, npm_path]
        

        
        for file in files_to_delete:
            try:
                if os.path.exists(file):
                    if os.path.isdir(file):
                        shutil.rmtree(file)
                    else:
                        os.remove(file)
            except:
                pass
        
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
    print(f"Server is running on port {ARGO_PORT}")
    print(f"Running done！")
    print(f"\nLogs will be delete in 90 seconds")
    server.serve_forever()
    
def run_async():
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(start_server()) 
    
    while True:
        time.sleep(3600)
        
if __name__ == "__main__":
    run_async()
