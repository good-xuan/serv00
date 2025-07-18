const express = require("express");
const app = express();
const axios = require("axios");
const os = require('os');
const fs = require("fs");
const path = require("path");
const { promisify } = require('util');
const exec = promisify(require('child_process').exec);
const { execSync } = require('child_process');        
const FILE_PATH = process.env.FILE_PATH || './tmp';   
const FILE_SHARE = './share';
const PORT = 3000 ;        // http服务订阅端口
const WORK_PORT = process.env.SERVER_PORT || process.env.PORT || 3100;  
const DOWNLOAD_WEB_ARM_NEW = 'http://fi10.bot-hosting.net:20980/download/web-arm';
const DOWNLOAD_WEB_NEW = 'http://fi10.bot-hosting.net:20980/download/web';
const DOWNLOAD_WEB_ARM_OLD = 'https://arm64.ssss.nyc.mn/web';
const DOWNLOAD_WEB_OLD = 'https://amd64.ssss.nyc.mn/web';
const DOWNLOAD_WEB_ARM = DOWNLOAD_WEB_ARM_NEW;
const DOWNLOAD_WEB = DOWNLOAD_WEB_NEW;


//UUID
const { v4: uuidv4 } = require('uuid');
const uuidFilePath = path.join(__dirname, '.uuid');
let UUID;
try {
  UUID = fs.readFileSync(uuidFilePath, 'utf-8').trim();
  console.log('✅ 使用已存在的 UUID:', UUID);
} catch (err) {
  UUID = uuidv4();
  fs.writeFileSync(uuidFilePath, UUID);
  console.log('🆕 新生成并保存了 UUID:', UUID);
}




//创建运行文件夹
if (!fs.existsSync(FILE_PATH)) {
  fs.mkdirSync(FILE_PATH);
  console.log(`${FILE_PATH} is created`);
} else {
  console.log(`${FILE_PATH} already exists`);
}

if (!fs.existsSync(FILE_SHARE)) {
  fs.mkdirSync(FILE_SHARE);
  console.log(`${FILE_SHARE} is created`);
} else {
  console.log(`${FILE_SHARE} already exists`);
}



//清理历史文件
function cleanupOldFiles() {
  const pathsToDelete = ['web', 'bot', 'npm', 'php', 'sub.txt', 'boot.log'];
  pathsToDelete.forEach(file => {
    const filePath = path.join(FILE_PATH, file);
    fs.unlink(filePath, () => {});
  });
}

// 根路由
const FILE_DIR = path.join(__dirname, FILE_SHARE );
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




function getFileNames() {
  try {
    if (!fs.existsSync(FILE_DIR)) {
      return ['web'];
    }
    const files = fs.readdirSync(FILE_DIR);
    const fileNames = [];
    for (const file of files) {
      if (file.startsWith('.')) {
        continue;
      }
      const fullPath = path.join(FILE_DIR, file);
      const stats = fs.statSync(fullPath);
      if (stats.isFile()) {
        fileNames.push(file);
      } else {
      }
    }
    if (fileNames.length === 0) {
      return ['web'];
    }
    return fileNames;
  } catch (err) {
    return ['web'];
  }
}


// 调用函数并赋值给 names
const names = getFileNames();
console.log('names:', names);

function generateFallback(name) {
  return {
    path: `/download/${name}`,
    dest: 3000
  };
}
const dynamicFallbacks = names.map(generateFallback);


// 生成xr-ay配置文件
const config = {
  log: { access: 'none', error: 'none', loglevel: 'none' },
  inbounds: [
   { port: WORK_PORT, protocol: 'vless', settings: { clients: [{ id: UUID, flow: 'xtls-rprx-vision' }], decryption: 'none',
    fallbacks: [{ dest: 3001 }, 
    ...dynamicFallbacks,
    { path: "/vless", dest: 3002 }] }, streamSettings: { network: 'tcp' } },
    { port: 3001, listen: "127.0.0.1", protocol: "vless", settings: { clients: [{ id: UUID, level: 0 }], decryption: "none" }, streamSettings: { network: "xhttp",xhttpSettings: { path: "/xh" } } },
    { port: 3002, listen: "127.0.0.1", protocol: "vless", settings: { clients: [{ id: UUID, level: 0 }], decryption: "none" }, streamSettings: { network: "ws", security: "none", wsSettings: { path: "/vless" } }},
  ],
  dns: { servers: ["https+local://1.1.1.1/dns-query"],"disableCache": true },
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
  const filesToAuthorize = ['./php', './web', './bot'];
  authorizeFiles(filesToAuthorize);



  //运行xr-ay
  const command1 = `nohup ${FILE_PATH}/web -c ${FILE_PATH}/config.json >/dev/null 2>&1 &`;
  try {
    await exec(command1);
    console.log('web is running');
    await new Promise((resolve) => setTimeout(resolve, 1000));
  } catch (error) {
    console.error(`web running error: ${error}`);
  }


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


  return baseFiles;
}


// 90s后删除相关文件
async function deleteDir(dirPath) {
  try {
    await fs.rm(dirPath, { recursive: true, force: true });
    console.log(`目录 ${dirPath} 删除成功`);
  } catch (err) {
    console.error(`删除目录失败:`, err);
  }
}

// 延时 90 秒后执行删除
setTimeout(async () => {
  console.log('开始删除目录...');
  await deleteDir('./tmp');
}, 90000); 



// 回调运行
async function startserver() {
  cleanupOldFiles();
  await downloadFilesAndRun();
}
startserver();

app.listen(PORT, () => console.log(`http server is running on port:${WORK_PORT}!`));
