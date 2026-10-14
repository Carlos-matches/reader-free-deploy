#!/usr/bin/env bash
# =============================================================================
# 阅读3服务器版 —— 免绑卡方案：构建可上传的部署包
# =============================================================================
#
# 用途：Bot-Hosting.net 等免费容器主机【没有 Docker】，需要直接上传 Node.js 文件。
#       官方只发布源码（不发布编译好的产物），所以必须在本地编译一次。
#
# 在【你自己的电脑】上运行本脚本（需要 Node.js 22+ 和 git），
# 产出一个 reader-bundle.zip，然后上传到免费主机即可。
#
# 用法：
#   bash build-bundle.sh
#
# =============================================================================

set -euo pipefail

REPO="${REPO:-https://github.com/hectorqin/reader.git}"
# 固定 commit，保证版本可复现（与 Docker 方案一致）
# 想升级时改成新的 commit sha
COMMIT="${COMMIT:-875fec84ddff0f76ab55d495cc428c658b80aeab}"

# 所有路径都基于本脚本所在目录，这样无论从哪里调用都能正确输出
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKDIR="${WORKDIR:-$PROJECT_DIR/.build}"
OUT="${OUT:-$PROJECT_DIR/reader-bundle.zip}"

RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YLW=$'\033[0;33m'; BLU=$'\033[0;34m'; NC=$'\033[0m'
info(){ echo "${BLU}[信息]${NC} $*"; }
ok(){ echo "${GRN}[成功]${NC} $*"; }
warn(){ echo "${YLW}[注意]${NC} $*"; }
die(){ echo "${RED}[错误]${NC} $*" >&2; exit 1; }

# ---------------------------- 前置检查 ---------------------------------------
command -v node >/dev/null 2>&1 || die "未找到 node。请先安装 Node.js 22+：https://nodejs.org/"
command -v npm  >/dev/null 2>&1 || die "未找到 npm。"
command -v git  >/dev/null 2>&1 || die "未找到 git。"
command -v zip  >/dev/null 2>&1 || warn "未找到 zip 命令，将尝试用 PowerShell 压缩（仅 Windows）"

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 22 ] || die "需要 Node.js 22 或更高版本，当前为 $(node -v)"

echo "=============================================================="
echo "  阅读3服务器版 —— 构建免绑卡部署包"
echo "=============================================================="
echo "  源码   : $REPO"
echo "  版本   : ${COMMIT:0:8}"
echo "  输出   : $OUT"
echo "=============================================================="
echo

# ---------------------------- 1. 拉取源码 ------------------------------------
info "步骤 1/5：拉取源码..."
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

# 优先用 git；某些网络环境会拦截 git 协议，
# 这时自动回退到 HTTPS 压缩包下载（更不容易被拦）。
SRC_OK=0

for attempt in 1 2 3; do
  if git clone --quiet --depth 50 "$REPO" "$WORKDIR/reader" 2>/dev/null; then
    SRC_OK=1
    break
  fi
  warn "git 克隆失败（第 $attempt 次），5 秒后重试..."
  rm -rf "$WORKDIR/reader"
  sleep 5
done

if [ "$SRC_OK" -ne 1 ]; then
  warn "git 克隆不可用，改用源码压缩包下载..."
  # 把 https://github.com/owner/repo.git 转成 tarball 地址
  SLUG="$(printf '%s' "$REPO" | sed -e 's|^https://github.com/||' -e 's|\.git$||')"
  TARBALL="https://codeload.github.com/${SLUG}/tar.gz/${COMMIT}"
  mkdir -p "$WORKDIR/reader"
  for attempt in 1 2 3; do
    if curl -fsSL "$TARBALL" -o "$WORKDIR/src.tar.gz" 2>/dev/null; then
      tar -xzf "$WORKDIR/src.tar.gz" -C "$WORKDIR/reader" --strip-components=1
      SRC_OK=1
      break
    fi
    warn "下载失败（第 $attempt 次），5 秒后重试..."
    sleep 5
  done
fi

[ "$SRC_OK" -eq 1 ] || die "无法获取源码。请检查网络，或设置代理后重试：
    export https_proxy=http://127.0.0.1:7890
    export http_proxy=http://127.0.0.1:7890"

cd "$WORKDIR/reader"
# 如果是 git 克隆，按 commit 取件；tarball 方式本就是该 commit
if [ -d .git ]; then
  git checkout --quiet "$COMMIT" 2>/dev/null || warn "无法切换到 $COMMIT（浅克隆可能未包含），改用当前分支"
fi
ok "源码就绪（${COMMIT:0:8}）"

# ---------------------------- 2. 编译服务端 ----------------------------------
info "步骤 2/5：编译服务端（TypeScript → JavaScript）..."
cd server
# 用 ci 保证依赖版本一致；若无 lock 文件则退回 install
if [ -f package-lock.json ]; then
  npm ci --silent --include=dev
else
  npm install --silent
fi
npm run build --silent
[ -f dist/main.js ] || die "编译失败：未生成 dist/main.js"
ok "服务端编译完成"

# ---------------------------- 3. 只保留运行时依赖 ----------------------------
info "步骤 3/5：裁剪为生产依赖（减小体积，适配 512MB 空间）..."
npm prune --omit=dev --silent
ok "已裁剪 devDependencies"

cd "$WORKDIR/reader"
# 记录版本，便于排查（tarball 方式没有 .git，直接用已知 commit）
printf '%s\n' "$COMMIT" > VERSION.txt

# ---------------------------- 4. 打包 ----------------------------------------
info "步骤 4/5：打包..."
# 只打包运行必需的文件：dist + node_modules + package.json
# 不含 src/test/tools，节省空间
STAGE="$WORKDIR/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"

cp -r server/dist "$STAGE/dist"
cp -r server/node_modules "$STAGE/node_modules"
cp server/package.json "$STAGE/package.json"
cp VERSION.txt "$STAGE/VERSION.txt"

# 说明文件，方便你在主机上配置
cat > "$STAGE/README-部署说明.txt" <<'EOF'
========================================================
 阅读3服务器版 —— 部署到免费主机
========================================================

【启动设置】
  Entry File / 启动文件:  dist/main.js

【环境变量】
  DATA_DIR    = .        （数据存当前目录，确保可写）
  BOOKS_DIR   = books    （把你的电子书放进 books 文件夹）
  PORT        = 主机分配给你的端口（通常由平台自动注入）
  ALLOW_REGISTRATION = false
  READER_TOKEN_SECRET = 自己设一个至少 16 位的随机字符串

【重要】
  1. Web 界面（H5）不包含在本包内。服务端会正常提供 /api 接口，
     但用浏览器直接打开根路径看不到界面。
     要完整界面请看 docs/前后端分离方案.md（前端可托管到 Netlify）。
  2. 主机只有 256MB 内存。实测本服务端占用约 100~115MB，
     余量充足，但请勿启用影音/媒体库功能（需要 ffmpeg，会超内存）。
  3. 请定期备份 data/ 目录（免费主机不提供备份）。

【启动命令】
  node dist/main.js
EOF

cd "$STAGE"
rm -f "$OUT" 2>/dev/null || true

if command -v zip >/dev/null 2>&1; then
  zip -qr "$OUT" . -x "*.map"
else
  # Windows 回退方案（把 bash 路径转成 Windows 路径给 PowerShell）
  OUT_WIN="$(cygpath -w "$OUT" 2>/dev/null || echo "$OUT")"
  powershell -NoProfile -Command "Compress-Archive -Path * -DestinationPath '$OUT_WIN' -Force"
fi

[ -f "$OUT" ] || die "打包失败：未生成 $OUT"

SIZE="$(du -h "$OUT" 2>/dev/null | cut -f1 || echo '未知')"
ok "打包完成：$OUT（$SIZE）"

# ---------------------------- 5. 提示 ----------------------------------------
echo
echo "=============================================================="
echo "${GRN}  构建完成！${NC}"
echo "=============================================================="
echo
echo "  产物：$OUT"
echo
echo "接下来的步骤（详见 docs/免绑卡部署.md）："
echo "  1. 到 https://sillydev.co.uk/ 注册（不需要银行卡）"
echo "  2. Create server → 运行时选 Node.js"
echo "  3. 用 File Manager 或 SFTP 上传并解压本压缩包"
echo "  4. Startup 里把启动文件设为： dist/main.js"
echo "  5. 添加环境变量（见压缩包内 README-部署说明.txt）"
echo "  6. 启动，然后在面板 Ports 里查看分配给你的网址"
echo
echo "  提示：Silly Development 永不需续期。"
echo "        若改用 Bot-Hosting.net（自带 HTTPS 域名），则需每 4 天手动续期。"
echo
