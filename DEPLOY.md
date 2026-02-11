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
