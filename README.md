<div align="center">

# 📚 阅读3服务器版 · 免费一键部署

**把 [hectorqin/reader](https://github.com/hectorqin/reader) 部署到云端，永久免费、数据不丢、一条命令搞定**

[![部署到 Google Cloud](https://img.shields.io/badge/一键部署-Google%20Cloud%20永久免费-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white)](#-方案一google-cloud永久免费推荐)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white)](#-方案三自己的电脑nasvps最省心)
[![License](https://img.shields.io/badge/License-AGPL--3.0-blue?style=for-the-badge)](LICENSE)

> 💡 **只想部署纯静态阅读器（不需要服务器）？**
> 见姊妹项目 👉 [reader-static](https://github.com/Carlos-matches/reader-static)

</div>

---

## 📖 这是什么？

**阅读（Legado）** 是一个开源的电子书阅读器。它的**服务器版（reader）** 让你可以：

- 📚 把电子书（EPUB / TXT / PDF / CBZ 漫画）放进自己的私人书库
- 🔗 导入**上千个书源**，在线搜索、追更网络小说
- ☁️ 多设备同步书架、阅读进度、书签和笔记
- 📱 用手机 App 或浏览器随时随地阅读

本仓库帮你**跳过所有繁琐步骤**，用最简单的方式把它部署到云端，并且**不花钱**。

---

## ⚠️ 先读这一段：关于「免费」的实话

我逐个查阅了各家平台的官方文档，结论必须如实告诉你：

> ### ❌ Netlify 无法运行这个服务器
>
> 你最初想用的 **Netlify 做不到**，这不是配置问题，是平台性质的限制：
>
> | 需求 | reader 的要求 | Netlify 提供 |
> |---|---|---|
> | 运行方式 | **常驻进程**（Node.js 服务器，24 小时运行） | 静态网页 + 无状态函数 |
> | 磁盘 | **可写且持久**（SQLite 数据库存账号、书架、进度） | 临时文件系统，随时清空 |
> | 超时 | 长时间运行（扫描书库、下载整本书） | 函数最多 10～26 秒 |
>
> Netlify 是**静态网站托管**平台，天生只能放网页，不能跑数据库服务器。硬塞进去会导致**每次访问数据全部丢失**。
>
> **另外**：你参考的 [Carlos-matches/--replit](https://github.com/Carlos-matches/--replit) 项目**已存档失效**（Replit 取消了免费部署），而 [hectorqin/reader](https://github.com/hectorqin/reader) 的 GitHub Releases **已被作者清空**——旧教程里下载 `.jar` 文件的命令现在全部失效了。本项目基于**当前最新的代码结构**重新编写。

### ✅ 那什么方案真的免费、数据还不丢？

我实测验证后，找到了真正的答案：

| 平台 | 真免费？ | 数据会丢吗？ | 需要信用卡？ | 评价 |
|---|---|---|---|---|
| **Silly Development** | ✅ **永久免费** | ✅ 512MB 持久磁盘 | ❌ **不需要** | 🏆 **不绑卡首选** |
| **Netlify + Silly 混合** | ✅ 永久免费 | ✅ 持久磁盘 | ❌ **不需要** | 🥇 **体验最好** |
| Bot-Hosting.net | ✅ 免费 | ✅ 512MB 持久磁盘 | ❌ **不需要** | ⚠️ 每 4 天要手动续期 |
| Google Cloud e2-micro | ✅ 永久免费 | ✅ 30GB 永久磁盘 | ⚠️ **需要** | 最稳，但要绑卡 |
| 自己的电脑 / NAS | ✅ 免费 | ✅ 本地磁盘 | ❌ 不需要 | 最省心、速度最快 |
| ~~Netlify（跑服务器）~~ | ❌ 跑不了 | ❌ | — | 但**可以放前端**！见下文 |
| ~~Render 免费版~~ | ⚠️ | ❌ **会丢** | ❌ | 免费版无持久磁盘 |
| ~~Railway~~ | ⚠️ 仅 30 天 | ⚠️ 仅 0.5GB | ❌ | 试用性质 |
| ~~Vercel / Cloudflare Pages~~ | ❌ 跑不了 | ❌ | — | 同为静态托管 |

---

## 🚫 不想绑卡？看这里（推荐）

**👉 详细教程：[docs/免绑卡部署.md](docs/免绑卡部署.md)**

### 首选：[Silly Development](https://sillydev.co.uk/) — 完全不需要银行卡

我亲自查阅了它官网和条款，确认：

| 项目 | 免费额度 |
|---|---|
| 价格 | **£0，永久免费，不是试用**（原文：not a trial）|
| 信用卡 | ❌ **不需要** |
| 内存 / 磁盘 | 256 MB / **512 MB 持久磁盘** |
| 续期 | ✅ **永不续期**（原文：no renewal button and no expiry timer）|
| 休眠 | ✅ **永不休眠** |
| 运行时 | Node.js ✅ |

官方明确支持 SQLite 持久化（原文："stays there across restarts"）。

**两个必须知道的限制**：
1. ⚠️ **不提供 HTTPS 域名**（原文：we do not provide a domain name or an HTTPS certificate）→ 用免费的 Cloudflare Tunnel 解决
2. ⚠️ **不提供备份**（原文：it is the only copy there is）→ 需自己定期下载 `/data`

> 需要 HTTPS 域名且能接受**每 4 天手动续期**的话，备选是 [Bot-Hosting.net](https://bot-hosting.net/)（自带 `*.apps.bot-hosting.cloud`）。

### 💡 你的 Netlify 想法是对的 —— 只是放错了位置

```
❌ Netlify 放整个服务器  → 跑不了（需常驻进程 + 数据库）
✅ Netlify 放前端网页    → 完美！前端是纯静态文件
   Silly Development 放后端
```

而且这是 **reader 官方支持的用法**，源码 `cors.ts` 注释原文：

> "**2. H5 served from somewhere else (a static host, a dev server on :5174)**"

**两边都免费，都不需要绑卡**。完整教程见 👉 [docs/前后端分离方案.md](docs/前后端分离方案.md)

---

## 🚀 方案一：Google Cloud（永久免费｜最稳定，但需绑卡）

> **为什么选它**：Google 的「Always Free」额度包含 **1 台 e2-micro 虚拟机 + 30GB 标准永久磁盘**，**每月都免费、永久有效、不会休眠**。跑 reader 绰绰有余。

### 你只需要做 3 件事

#### 第 1 步：准备 Google Cloud 账号

1. 打开 <https://cloud.google.com/>，点击右上角 **「开始使用」** 注册
2. 注册需要**绑定信用卡或借记卡**用于身份验证（**不会扣费**，Google 会做 1 美元左右的预授权然后退还）
3. 注册后会赠送 **$300 试用金**（90 天有效）。**即使试用金用完，Always Free 额度依然永久免费**，本方案完全在免费额度内
4. 创建或选择一个项目，记下**项目 ID**（形如 `my-project-123456`）

#### 第 2 步：安装 Google Cloud CLI

| 系统 | 安装方式 |
|---|---|
| **Windows** | 下载安装包：<https://cloud.google.com/sdk/docs/install#windows> |
| **macOS** | `brew install --cask google-cloud-sdk` |
| **Linux** | `curl https://sdk.cloud.google.com \| bash && exec -l $SHELL` |

安装完成后，打开终端执行：

```bash
# 登录你的 Google 账号（会弹出浏览器）
gcloud auth login

# 设置项目（把下面的 ID 换成你自己的项目 ID）
gcloud config set project 你的项目ID
```

#### 第 3 步：运行一键部署脚本

```bash
# 进入本仓库的 scripts 目录
cd scripts

# 运行部署脚本（可选：用 INVITE_CODE 设置注册邀请码）
bash deploy-gcp.sh
```

**脚本会自动完成全部工作**（约 2～3 分钟）：
- ✅ 启用所需 API
- ✅ 生成随机管理密钥
- ✅ 预留固定公网 IP（重启不变）
- ✅ 配置防火墙
- ✅ 创建 30GB 永久数据盘
- ✅ 创建 e2-micro 虚拟机
- ✅ 自动安装 Docker 并启动 reader

完成后终端会显示：

```
==============================================================
  部署完成！
==============================================================

  访问地址：http://12.34.56.78/

  管理密钥（请妥善保存）：xxxxxxxxxxxxxxxx
==============================================================
```

#### 第 4 步：使用

1. **等 1～2 分钟**（首次要下载 Docker 镜像）
2. 浏览器打开 `http://你的公网IP/`
3. **第一个注册的账号自动成为管理员** 👑
4. 进去后就可以添加书籍、导入书源了（见下方教程）

> 💡 **打不开？** 等待时间不够。查看进度：
> ```bash
> gcloud compute ssh reader-server --zone us-west1-b --command "sudo tail -f /var/log/reader-bootstrap.log"
> ```

<details>
<summary><b>🔧 进阶：常用管理命令（点击展开）</b></summary>

```bash
# SSH 登录服务器
gcloud compute ssh reader-server --zone us-west1-b

# 查看服务状态
sudo systemctl status reader

# 查看实时日志
sudo journalctl -u reader -f

# 重启服务
sudo systemctl restart reader

# 查看磁盘使用
df -h /data

# 停止虚拟机（停止后计算资源不免费占用，但磁盘仍免费保留）
gcloud compute instances stop reader-server --zone us-west1-b

# 重新开机
gcloud compute instances start reader-server --zone us-west1-b
```

**关于费用安全**：e2-micro 在 `us-west1` / `us-central1` / `us-east1` 三个区域每月免费 744 小时（正好一整月），30GB 标准磁盘也免费。只要不加别的资源就不会扣费。建议在 Google Cloud 控制台设置**预算提醒**以防万一。

</details>

---

## 💻 方案三：自己的电脑 / NAS / VPS（最省心）

> 有闲置电脑、NAS 或树莓派？用这个方法**零成本、速度最快**（本地网络读大文件飞快）。

```bash
# 1. 复制配置文件
cp .env.example .env

# 2. 编辑 .env，至少设置书库路径 BOOKS_PATH
#    Windows:   BOOKS_PATH=D:/books
#    Mac/Linux: BOOKS_PATH=/Users/你的用户名/books

# 3. 启动
docker compose up -d

# 4. 打开浏览器访问
#    http://localhost:5888
```

停止：`docker compose down` ｜ 更新：`docker compose pull && docker compose up -d`

---

## 🔀 方案二：Railway（想先快速试试）

Railway 免费计划**无需信用卡**，含 **0.5GB 持久卷**：

1. 打开 <https://railway.com/>，用 GitHub 账号注册
2. 点 **New Project → Deploy from Docker Image**
3. 镜像填：`docker.cnb.cool/hectorqin/reader:875fec84`
4. 添加环境变量：`DATA_DIR=/data`、`BOOKS_DIR=/books`
5. 在服务设置里 **Add Volume**，挂载路径填 `/data`
6. 在 **Settings → Networking** 生成公网域名

> ⚠️ **注意**：Railway 免费计划是「30 天 $5 额度」的试用性质，长期使用可能产生约 $1/月的费用，且 0.5GB 卷较小。**长期免费建议用方案一。**

---

## 📚 使用教程

### 一、添加书籍

**方法 A：网页上传**（需可写挂载）
1. 用管理员账号登录 → 进入**书库**页面
2. 点**上传**按钮，选择 EPUB / TXT / PDF 文件

**方法 B：放入书库目录**（推荐，适合大批量）
- **Google Cloud**：用 `gcloud compute scp` 上传
  ```bash
  gcloud compute scp ./我的书.epub reader-server:/tmp/ --zone us-west1-b
  gcloud compute ssh reader-server --zone us-west1-b --command "sudo mv /tmp/*.epub /books/"
  ```
- **本地 Docker**：直接把书复制进 `BOOKS_PATH` 目录
- 放入后等待自动扫描（默认 30 分钟），或到管理后台手动触发扫描

**支持的格式**：EPUB、TXT、PDF、CBZ/ZIP 漫画、图片目录

### 二、导入书源（搜书 / 追更的关键）🔗

书源让 reader 能搜索和在线阅读全网小说。**没有书源只能读自己上传的书。**

1. 管理员登录 → 左侧菜单 **书源管理**
2. 点 **导入书源**
3. 三种导入方式：
   - **网络导入**（最常用）：粘贴书源订阅链接，例如
     ```
     https://raw.githubusercontent.com/shidahuilang/shuyuan/shuyuan/book.json
     ```
   - **本地导入**：上传 `.json` 书源文件
   - **手动输入**：粘贴单条书源 JSON

4. 导入后回到**发现**页，就能搜索全网书籍了

> 📌 **书源去哪找**：在 GitHub 搜索关键词 `阅读3.0 书源` / `legado 书源` / `shuyuan`，能找到大量免费共享书源合集。书源失效是常态，多导入几份备用。

### 三、接入客户端

| 客户端 | 说明 |
|---|---|
| **浏览器** | 直接访问你的部署地址，功能完整，支持手机浏览器 |
| **Android App** | 下载 [Legado 阅读](https://github.com/gedoor/legado) → 书源管理 → 添加「阅读3.0 服务器版」→ 填入你的地址和账号 |
| **iOS** | 用 Safari 打开地址 → 分享 → **添加到主屏幕**（PWA，像 App 一样） |
| **OPDS** | 其他阅读器可用 OPDS 协议接入，地址：`http://你的地址/api/v1/opds` |

### 四、数据备份（重要！）

**所有数据都在 `/data` 目录**（SQLite 数据库、账号、进度、密钥）。

<details>
<summary><b>Google Cloud 备份方法</b></summary>

```bash
# 登录服务器
gcloud compute ssh reader-server --zone us-west1-b

# 停止服务保证数据一致
sudo systemctl stop reader

# 打包数据
sudo tar czf /tmp/reader-backup-$(date +%F).tar.gz -C /data .

# 退出后下载到本地
exit
gcloud compute scp reader-server:/tmp/reader-backup-*.tar.gz ./ --zone us-west1-b

# 记得重新启动服务
gcloud compute ssh reader-server --zone us-west1-b --command "sudo systemctl start reader"
```

</details>

<details>
<summary><b>本地 Docker 备份方法</b></summary>

```bash
docker compose stop
tar czf reader-backup-$(date +%F).tar.gz ./data
docker compose start
```

</details>

> 🔑 **千万别丢 `data/token.secret`**，否则所有人需要重新登录。

---

## ❓ 常见问题

<details>
<summary><b>真的不会扣费吗？</b></summary>

本方案**完全在 Google Cloud Always Free 额度内**：1 台 e2-micro（744 小时/月，正好覆盖整月）+ 30GB 标准磁盘。只要：
- ❌ 不添加额外磁盘或提高机器配置
- ❌ 不启用 GPU
- ✅ 在美国三个指定区域部署（脚本已限制）

就是完全免费的。建议在控制台设置**预算提醒**（Billing → Budgets）做双保险。
</details>

<details>
<summary><b>1GB 内存够用吗？</b></summary>

够。部署脚本会自动加 **2GB swap** 防止大书库扫描时内存不足。日常阅读和搜索完全流畅。只有同时扫描数万本书时可能略慢。
</details>

<details>
<summary><b>网页打不开 / 502？</b></summary>

1. 首次部署需等 2～3 分钟下载镜像
2. 检查服务状态：`sudo systemctl status reader`
3. 查看日志：`sudo journalctl -u reader -n 100`
4. 确认防火墙放行 80 端口
</details>

<details>
<summary><b>想升级到新版本？</b></summary>

```bash
# SSH 登录后
sudo nano /etc/systemd/system/reader.service   # 改镜像标签
sudo systemctl daemon-reload
sudo systemctl restart reader
```
最新标签见 <https://cnb.cool/hectorqin/reader/-/packages>
</details>

<details>
<summary><b>书源导入失败 / 搜不到书？</b></summary>

书源本身失效是常态。解决方法：多导入几份不同的书源合集；在「书源管理」里逐个启用/禁用测试。
</details>

<details>
<summary><b>能部署到 Netlify / Vercel 吗？</b></summary>

**不能。** 它们是静态托管平台，无法运行需要常驻进程和数据库的服务器。详见文档顶部说明。
</details>

---

## 📁 仓库结构

```
.
├── scripts/
│   ├── deploy-gcp.sh       # ⭐ Google Cloud 一键部署脚本（需绑卡）
│   ├── build-bundle.sh     # ⭐ 免绑卡方案：构建可上传的部署包
│   └── cloud-init.yaml     # 虚拟机首次启动自动配置
├── docs/
│   ├── 免绑卡部署.md        # ⭐ 不用信用卡的方案（Silly Development）
│   ├── 前后端分离方案.md    # ⭐ Netlify 前端 + 免费后端（推荐）
│   ├── 一键部署教程.md      # Google Cloud 图文教程
│   ├── 平台对比.md          # 各平台免费方案核实对比
│   └── 研究原始记录.md      # 平台调研原始数据
├── docker-compose.yml      # 本地/NAS/VPS 部署（最省心）
├── render.yaml             # Render 部署（需付费才有持久磁盘）
├── .env.example            # 环境变量模板
└── README.md
```

### 我该选哪个？

| 你的情况 | 推荐方案 |
|---|---|
| **不想绑卡** | [免绑卡部署](docs/免绑卡部署.md)（Silly Development）|
| **不想绑卡 + 想要网页界面** | [前后端分离方案](docs/前后端分离方案.md)（Netlify + Silly）|
| 有闲置电脑 / NAS | [docker-compose.yml](docker-compose.yml)（最快最省心）|
| 能绑卡、想要最稳 | [一键部署教程](docs/一键部署教程.md)（Google Cloud）|

---

## 🙏 致谢与声明

- 感谢 [hectorqin/reader](https://github.com/hectorqin/reader) 提供的优秀开源项目（AGPL-3.0）
- 本项目仅为**部署脚本与教程**，不含 reader 源码，遵循同样的 AGPL-3.0 协议
- 请遵守当地法律法规，仅用于个人合法阅读用途
- 本文档中所有平台的免费政策均于 **2026-10** 核实自官方页面，平台政策可能变化

<div align="center">

**如果这个项目帮到了你，请给个 ⭐ Star 支持一下！**

</div>
