# 软件宣传与下载站点

静态宣传页 + 下载目录 + Nginx 配置 + 自动化发布与统计脚本。

## 目录结构

```
.
├── index.html              # 宣传主页（动画、下载入口、校验说明）
├── downloads/               # 软件安装包目录
│   ├── README.md
│   ├── checksums.json      # 由 scripts/checksums.sh 生成，供首页展示
│   └── checksums.txt       # 同上，便于命令行校验
├── nginx/
│   └── sites-available-my-site.conf   # Nginx 配置示例
├── scripts/
│   ├── release.sh          # 自动化发布：复制构建产物并更新校验
│   ├── checksums.sh        # 为 downloads/ 生成 SHA256 与 checksums.json
│   └── analyze-downloads.sh # 解析 Nginx 日志统计下载量与流量
└── README.md
```

## 本地预览

在项目根目录起一个静态服务即可：

```bash
# Python 3
python -m http.server 8080

# Node (npx)
npx serve -l 8080
```

浏览器打开 `http://localhost:8080`。首页会尝试加载 `downloads/checksums.json`；若存在则展示下载列表与 SHA256，否则显示占位说明。

## 自动化发布（Shell）

### 1. 生成校验信息（仅更新 checksums）

```bash
chmod +x scripts/*.sh
./scripts/checksums.sh
# 或指定目录
./scripts/checksums.sh /path/to/downloads
```

会在 `downloads/` 下生成 `checksums.json` 和 `checksums.txt`。

### 2. 发布新版本（复制文件 + 更新校验）

```bash
# 交互式：从默认构建目录选择要发布的文件
./scripts/release.sh

# 发布单个文件
./scripts/release.sh /path/to/app-1.0.0.apk

# 发布某目录下所有匹配文件（apk/exe/zip/dmg 等）
./scripts/release.sh /path/to/build/
```

可选环境变量：

- `RELEASE_SOURCE_DIR`：未传参时使用的“构建产物”目录，默认 `./build`
- `RELEASE_EXTENSIONS`：要复制的扩展名，逗号分隔，如 `apk,exe,zip,dmg`

发布脚本会把新文件复制到 `downloads/`，旧版本会备份到 `downloads/archive/`，然后自动执行 `checksums.sh`。

### 3. 下载量统计（Nginx 日志）

```bash
# 使用默认 /var/log/nginx/access.log（需有读权限）
./scripts/analyze-downloads.sh

# 或指定日志路径
./scripts/analyze-downloads.sh /var/log/nginx/access.log
```

会统计包含 `/downloads/` 的请求数、总流量，并按文件输出；同时生成 `reports/download-stats-YYYYMMDD.csv`。

## 部署到 Linux（Nginx）

**详细步骤见 [DEPLOY.md](DEPLOY.md)**，包括：上传文件（scp/rsync/git）、安装 Nginx、配置站点、开启 HTTPS（Certbot）、更新与发布。

简要步骤：

1. 将站点文件放到服务器（如 `/var/www/my-site`），可用 `scp -r index.html downloads nginx scripts 用户@服务器IP:~/web/` 再在服务器上 `cp` 到 `/var/www/my-site`。
2. 复制 `nginx/sites-available-my-site.conf` 到 `/etc/nginx/sites-available/my-site`，把 `your_domain.com` 和 `root /var/www/my-site` 改成你的域名和路径。
3. 启用并重载：`sudo ln -sf /etc/nginx/sites-available/my-site /etc/nginx/sites-enabled/`，`sudo nginx -t && sudo systemctl reload nginx`。
4. （推荐）有域名时用 Certbot 申请 HTTPS：`sudo certbot --nginx -d 你的域名`。

## 增强建议（与 Gemini 建议对应）

- **HTTPS**：用 Certbot + Let's Encrypt，配置见上。
- **文件完整性**：首页和 `downloads/checksums.txt` 均提供 SHA256，用户可自行校验。
- **CDN**：可将静态资源或整个站点接入 Cloudflare 等 CDN。
- **日志分析**：使用 `scripts/analyze-downloads.sh` 定时分析 Nginx access.log，生成 CSV 报表。

## 技术栈

- 纯静态：HTML + CSS（动画、渐变、网格背景）+ 少量 JS（拉取 `checksums.json`、复制校验码）。
- 字体：Google Fonts（Outfit、JetBrains Mono）。
- 脚本：Bash，适用于 Linux/macOS。
