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
WORKDIR="${WORKDIR:-./build}"
OUT="${OUT:-./reader-bundle.zip}"

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
git clone --quiet "$REPO" "$WORKDIR/reader"
cd "$WORKDIR/reader"
git checkout --quiet "$COMMIT" 2>/dev/null || warn "无法切换到 $COMMIT，改用默认分支"
ok "源码就绪（$(git rev-parse --short HEAD)）"

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

cd ..
# 记录版本，便于排查
printf '%s\n' "$(git rev-parse HEAD)" > VERSION.txt

# ---------------------------- 4. 打包 ----------------------------------------
info "步骤 4/5：打包..."
# 只打包运行必需的文件：dist + node_modules + package.json
# 不含 src/test/tools，节省空间
STAGE="../stage"
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
     要完整界面请看 README 的「前端部署」说明（可托管到 Netlify 等静态平台）。
  2. 主机只有 256MB 内存，建议不要启用影音扫描。
  3. 免费套餐需要每 4 天手动续期一次，否则服务会被删除。

【启动命令】
  node dist/main.js
EOF

cd "$STAGE"
rm -f "../$OUT" 2>/dev/null || true

if command -v zip >/dev/null 2>&1; then
  zip -qr "../$OUT" . -x "*.map"
else
  # Windows 回退方案
  powershell -NoProfile -Command "Compress-Archive -Path * -DestinationPath '../$OUT' -Force"
fi

cd ../..
[ -f "$OUT" ] || die "打包失败"

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
echo "接下来的步骤："
echo "  1. 到 https://bot-hosting.net/ 用 GitHub 或 Discord 登录（不需要银行卡）"
echo "  2. 创建 Deployment，运行时选择 Node.js"
echo "  3. 用面板的 File Manager 或 SFTP 上传并解压本压缩包"
echo "  4. 在 Startup 里把启动文件设为： dist/main.js"
echo "  5. 添加环境变量（见压缩包内 README-部署说明.txt）"
echo "  6. 启动，然后在 Ports 里查看分配给你的网址"
echo
warn "注意：免费套餐需每 4 天手动续期一次。"
echo
