# 把网站部署到 Linux 服务器

按下面步骤把本地的 `d:\web` 网站搬到 Linux 服务器并用 Nginx 对外提供访问。

---

## 一、前提条件

- 一台有公网 IP 的 Linux 服务器（Ubuntu / Debian / CentOS 等）
- 能通过 SSH 登录：`ssh 用户名@服务器IP`
- （可选）已有一个域名并解析到该服务器 IP

---

## 二、上传网站文件到服务器

任选一种方式，把本地项目传到服务器。

### 方式 1：用 SCP 上传（Windows 上可用 PowerShell 或 Git Bash）

在 **本地** 项目目录（`d:\web`）下执行，把下面 `用户@服务器IP` 换成你的：

```bash
# 上传整个项目到服务器家目录下的 web 文件夹
scp -r index.html downloads nginx scripts README.md 用户@服务器IP:~/web/
```

若服务器上没有 `web` 目录，先 SSH 登录后建一个再传：

```bash
ssh 用户@服务器IP "mkdir -p ~/web"
scp -r index.html downloads nginx scripts README.md 用户@服务器IP:~/web/
```

### 方式 2：用 rsync（更省流量，适合多次更新）

```bash
rsync -avz --exclude '.git' ./ 用户@服务器IP:~/web/
```

### 方式 3：服务器上拉 Git（若项目在 Git 仓库里）

```bash
ssh 用户@服务器IP
cd ~
git clone https://你的仓库地址.git web
cd web
```

---

## 三、在服务器上安装 Nginx

SSH 登录服务器后执行：

**Ubuntu / Debian：**

```bash
sudo apt update
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```

**CentOS / RHEL：**

```bash
sudo yum install -y nginx
# 或
sudo dnf install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
```

---

## 四、把网站放到 Nginx 的目录并设权限

常见做法是放到 `/var/www/` 下，例如 `/var/www/my-site`：

```bash
# 创建网站目录
sudo mkdir -p /var/www/my-site

# 把上传的 ~/web 里的内容复制过去（按你实际路径改）
sudo cp -r ~/web/index.html ~/web/downloads ~/web/scripts /var/www/my-site/

# 设置权限：Nginx 一般用 www-data（Debian/Ubuntu）或 nginx（CentOS）用户
sudo chown -R www-data:www-data /var/www/my-site
# CentOS 用：sudo chown -R nginx:nginx /var/www/my-site

sudo chmod -R 755 /var/www/my-site
```

若你希望用别的路径（如 `/home/你的用户/my-site`），也可以，后面 Nginx 配置里的 `root` 改成这个路径即可。

---

## 五、配置 Nginx

1. 复制项目里的 Nginx 配置到系统目录：

```bash
sudo cp /var/www/my-site/nginx/sites-available-my-site.conf /etc/nginx/sites-available/my-site
```

2. 用编辑器把配置里的 **域名** 和 **路径** 改成你的：

```bash
sudo nano /etc/nginx/sites-available/my-site
```

需要改的两处：

- `server_name your_domain.com;` → 改成你的域名，例如 `download.example.com`；没有域名就改成 `_` 或服务器 IP
- `root /var/www/my-site;` → 若网站不在 `/var/www/my-site`，改成你实际路径（下面两处 `alias` 里的路径也要一起改）

3. 启用站点并重载 Nginx：

```bash
sudo ln -sf /etc/nginx/sites-available/my-site /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

`nginx -t` 通过就说明配置没问题。若之前有默认站点占 80 端口，可删掉默认站点再启用你的：

```bash
sudo rm -f /etc/nginx/sites-enabled/default
```

4. 在浏览器访问：

- 用域名：`http://你的域名`
- 用 IP：`http://服务器IP`

能看到首页说明部署成功。

---

## 六、（推荐）开启 HTTPS（Let's Encrypt）

有域名时建议用 Certbot 申请免费证书：

```bash
# Ubuntu/Debian
sudo apt install -y certbot python3-certbot-nginx

# 申请证书并自动改 Nginx 配置（把 your_domain.com 换成你的域名）
sudo certbot --nginx -d your_domain.com
```

按提示选是否重定向 HTTP 到 HTTPS。证书会自动续期。

若你用的是项目里「注释掉的 HTTPS server 块」，Certbot 一般会自己插入 `listen 443 ssl` 等配置；你也可以在 Certbot 完成后，按需把项目里那份 HTTPS 注释取消并改成 Certbot 给的路径。

---

## 七、之后更新网站内容

### 只更新页面或脚本

在本地改好后，再传一次文件到服务器，然后覆盖到网站目录：

```bash
# 本地执行（示例：只传 index.html 和 scripts）
scp index.html 用户@服务器IP:~/web/
scp -r scripts 用户@服务器IP:~/web/

# 登录服务器后覆盖到网站目录
ssh 用户@服务器IP
sudo cp ~/web/index.html /var/www/my-site/
sudo cp -r ~/web/scripts /var/www/my-site/
sudo chown -R www-data:www-data /var/www/my-site
```

### 发布新版本安装包并更新校验

在服务器上进入网站目录执行发布脚本：

```bash
cd /var/www/my-site
chmod +x scripts/*.sh
./scripts/release.sh /path/to/your/app-1.0.0.apk
```

或先把安装包传到服务器某目录，再执行：

```bash
scp my-app.apk 用户@服务器IP:/tmp/
ssh 用户@服务器IP
cd /var/www/my-site && ./scripts/release.sh /tmp/my-app.apk
```

---

## 八、常用命令速查

| 操作           | 命令 |
|----------------|------|
| 重载 Nginx     | `sudo systemctl reload nginx` |
| 查看 Nginx 状态 | `sudo systemctl status nginx` |
| 查看 Nginx 错误日志 | `sudo tail -f /var/log/nginx/error.log` |
| 仅更新校验信息 | `cd /var/www/my-site && ./scripts/checksums.sh` |
| 统计下载量     | `./scripts/analyze-downloads.sh /var/log/nginx/access.log` |

---

## 九、没有域名时

没有域名也可以部署：

1. 上传和 Nginx 配置步骤同上。
2. 在 Nginx 配置里把 `server_name your_domain.com;` 改成 `server_name _;` 或直接写服务器公网 IP。
3. 用浏览器访问 `http://服务器IP` 即可。

没有域名时无法用 Let's Encrypt 申请证书，只能使用 HTTP；若需要 HTTPS，可考虑用自签名证书（浏览器会提示不安全，仅适合内网或测试）。

---

按上述步骤做完，网站就已在 Linux 服务器上跑起来了；后续更新只需传文件或执行 `release.sh` / `checksums.sh` 即可。

---

## 故障排除

### 报错：`/usr/bin/env: 'bash\r': No such file or directory`

**原因**：脚本在 Windows 下编辑过，使用了 Windows 换行符（CRLF），Linux 无法识别。

**在服务器上执行**（去掉行尾的 `\r`）：

```bash
cd /var/www/my-site
sed -i 's/\r$//' scripts/release.sh scripts/checksums.sh scripts/analyze-downloads.sh
```

然后重新运行：

```bash
./scripts/release.sh ./downloads/app-release.apk
```

**以后**：项目里已加 `.gitattributes`，用 Git 克隆或拉取时 `*.sh` 会自动用 Unix 换行；在 Windows 上编辑脚本时，用 VS Code / Cursor 把右下角“CRLF”改成“LF”再保存，可避免再次出现此问题。

### 访问 /downloads/ 出现 403 Forbidden

**原因**：Nginx 进程用户（Ubuntu 上多为 `www-data`）没有权限读网站目录或 `downloads` 目录。

**在服务器上执行**（按你的实际路径改 `/var/www/my-site`）：

```bash
# 把网站目录及其子目录的所有者改为 Nginx 用户
sudo chown -R www-data:www-data /var/www/my-site

# 保证目录可被 Nginx 进入、文件可读
sudo chmod 755 /var/www/my-site
sudo chmod 755 /var/www/my-site/downloads
sudo chmod 644 /var/www/my-site/downloads/*

# 若 downloads 下有子目录（如 archive），也要可读可进
sudo find /var/www/my-site/downloads -type d -exec chmod 755 {} \;
sudo find /var/www/my-site/downloads -type f -exec chmod 644 {} \;
```

然后重载 Nginx 再试：

```bash
sudo systemctl reload nginx
```

再在浏览器打开 `https://crywal.best/downloads/`，应能看见目录列表或文件。若仍 403，可查看 Nginx 错误日志：`sudo tail -20 /var/log/nginx/error.log`。

**子目录（如 `/downloads/archive/`）也 403**：多半是权限/属主问题。在服务器上执行：
```bash
sudo chown -R www-data:www-data /var/www/my-site/downloads
sudo find /var/www/my-site/downloads -type d -exec chmod 755 {} \;
sudo find /var/www/my-site/downloads -type f -exec chmod 644 {} \;
sudo systemctl reload nginx
```

### 错误：directory index of ".../downloads/" is forbidden

**原因**：访问的是 **HTTPS**（如 `https://www.crywal.best/downloads/`），但处理 443 的 server 里没有对 `/downloads` 开启目录列表（`autoindex on`），或根本没有 `location /downloads`。

**处理**：在服务器上编辑 Nginx 里**监听 443** 的那段配置，为 `/downloads` 加上和 80 一样的 location（含 `autoindex on`）。

1. 查看当前站点配置（含 Certbot 生成的 443）：
   ```bash
   sudo grep -l "crywal.best\|my-site" /etc/nginx/sites-enabled/*
   ```
   或直接：
   ```bash
   sudo nano /etc/nginx/sites-available/my-site
   ```
   若 Certbot 把 HTTPS 写到了 `sites-available/default` 或别的文件，就编辑那个文件。

2. 找到 **listen 443** 的 `server { ... }`，在其中的 `location / { ... }` 后面加上：
   ```nginx
   location /downloads {
       alias /var/www/my-site/downloads/;
       autoindex on;
       autoindex_exact_size off;
       autoindex_localtime on;
       add_header Content-Disposition "attachment";
   }
   ```
   若已有 `location /downloads` 但没有 `autoindex on;`，补上这一行即可。

3. 检查并重载：
   ```bash
   sudo nginx -t && sudo systemctl reload nginx
   ```
   再访问 `https://www.crywal.best/downloads/` 应能看见目录列表。

### 下载得到 .htm 或 .apk 无法下载（实际下到的是网页）

**原因**：要么服务器上**没有该文件**或**权限不对**，Nginx 返回 404/403 的 HTML 页面，浏览器把它当“下载”保存成 .htm；要么 Nginx 没有把文件按二进制输出。

**1）确认文件在服务器上且可读**

在服务器上执行：

```bash
ls -la /var/www/my-site/downloads/
```

确认里面有你的 .apk 等文件，且所有者/权限正确：

```bash
sudo chown -R www-data:www-data /var/www/my-site/downloads
sudo chmod 644 /var/www/my-site/downloads/*.apk
```

**2）让 Nginx 按二进制提供下载**

在**处理 80 和 443** 的 `location /downloads` 里加上：

```nginx
default_type application/octet-stream;
```

例如该块为：

```nginx
location /downloads {
    alias /var/www/my-site/downloads/;
    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;
    default_type application/octet-stream;   # 加这一行
    add_header Content-Disposition "attachment";
}
```

然后执行：`sudo nginx -t && sudo systemctl reload nginx`，再试下载。若仍得到 .htm，用浏览器 F12 → Network 看该请求的状态码（404/403 等）和响应内容，便于继续排查。

### 点「Open Download folder」弹出“另存为”保存 HTML，而不是显示下载列表

**原因**：Nginx 在 `location /downloads` 里对所有响应（包括目录列表页）都加了 `Content-Disposition: attachment`，浏览器就会把目录列表当成“附件”下载，弹出“另存为”保存成 .htm。

**处理**：只对**具体文件**（如 /downloads/xxx.apk）加“下载”头，对**目录**（/downloads/）不加，让浏览器直接显示列表。

在 80 和 443 的 server 里，把原来的一个 `location /downloads` 拆成两个：

1. **具体文件**（正则优先匹配）：
   ```nginx
   location ~ ^/downloads/(.+)$ {
       alias /var/www/my-site/downloads/$1;
       default_type application/octet-stream;
       add_header Content-Disposition "attachment";
   }
   ```
2. **目录列表**（不加 attachment）：
   ```nginx
   location /downloads {
       alias /var/www/my-site/downloads/;
       autoindex on;
       autoindex_exact_size off;
       autoindex_localtime on;
   }
   ```

然后执行：`sudo nginx -t && sudo systemctl reload nginx`。再点「Open Download folder」应直接打开下载列表页，点具体 .apk 才会触发下载。
