#!/usr/bin/env bash
# =============================================================================
# 阅读3服务器版 —— Google Cloud 永久免费 一键部署脚本
# =============================================================================
#
# 这个脚本会在你的 Google Cloud 账号里自动创建：
#   - 一台 e2-micro 虚拟机（永久免费额度内，不产生费用）
#   - 一块 30GB 永久磁盘（永久免费额度内，数据不会丢）
#   - 防火墙规则（开放 80 端口）
#   - 自动安装 Docker 并启动 reader 服务
#
# 用法（在你自己的电脑上运行，需要已安装并登录 gcloud）：
#   bash deploy-gcp.sh
#
# 前提：安装 Google Cloud CLI 并登录
#   https://cloud.google.com/sdk/docs/install
#   gcloud auth login
#   gcloud config set project <你的项目ID>
#
# =============================================================================

set -euo pipefail

# ---------------------------- 可配置项 ---------------------------------------
# 虚拟机所在区域。必须从下面三个"永久免费"区域中选一个（离你越近越快）：
#   us-west1     = 美国俄勒冈（亚洲用户通常这个最快）
#   us-central1  = 美国爱荷华
#   us-east1     = 美国南卡罗来纳
REGION="${REGION:-us-west1}"
ZONE="${ZONE:-${REGION}-b}"

VM_NAME="${VM_NAME:-reader-server}"
DISK_NAME="${DISK_NAME:-reader-data}"
DISK_SIZE_GB="${DISK_SIZE_GB:-30}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-micro}"
FIREWALL_RULE="${FIREWALL_RULE:-allow-reader-http}"
STATIC_IP_NAME="${STATIC_IP_NAME:-reader-ip}"

# reader 容器镜像（已核实可公开拉取，commit 标签固定版本）
IMAGE="${IMAGE:-docker.cnb.cool/hectorqin/reader:875fec84}"

# 注册邀请码：留空则关闭注册（首个账号仍可注册并成为管理员）
INVITE_CODE="${INVITE_CODE:-}"
# 是否允许注册
ALLOW_REGISTRATION="${ALLOW_REGISTRATION:-false}"

# ---------------------------- 颜色输出 ---------------------------------------
RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YLW=$'\033[0;33m'; BLU=$'\033[0;34m'; NC=$'\033[0m'
info()  { echo "${BLU}[信息]${NC} $*"; }
ok()    { echo "${GRN}[成功]${NC} $*"; }
warn()  { echo "${YLW}[注意]${NC} $*"; }
err()   { echo "${RED}[错误]${NC} $*" >&2; }
die()   { err "$*"; exit 1; }

# ---------------------------- 前置检查 ---------------------------------------
command -v gcloud >/dev/null 2>&1 || die "未找到 gcloud。请先安装 Google Cloud CLI：https://cloud.google.com/sdk/docs/install"

PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
[ -n "$PROJECT" ] && [ "$PROJECT" != "(unset)" ] || die "未设置项目。请运行：gcloud config set project <你的项目ID>"

# 校验区域在免费列表内
case "$REGION" in
  us-west1|us-central1|us-east1) ;;
  *) die "区域 '$REGION' 不在永久免费列表内。请使用 us-west1 / us-central1 / us-east1。" ;;
esac

echo
echo "=============================================================="
echo "  阅读3服务器版 —— Google Cloud 永久免费部署"
echo "=============================================================="
echo "  项目 ID    : $PROJECT"
echo "  区域 / 可用区: $REGION / $ZONE"
echo "  机型       : $MACHINE_TYPE  (永久免费)"
echo "  数据盘     : ${DISK_SIZE_GB}GB  (永久免费上限 30GB)"
echo "  镜像       : $IMAGE"
echo "=============================================================="
echo

# ---------------------------- 1. 启用 API ------------------------------------
info "步骤 1/7：启用所需 API（Compute Engine）..."
gcloud services enable compute.googleapis.com --project "$PROJECT" || die "启用 API 失败"
ok "API 已启用"

# ---------------------------- 2. 生成密钥 ------------------------------------
info "步骤 2/7：生成随机管理密钥..."
if [ -n "${READER_TOKEN_SECRET:-}" ]; then
  TOKEN_SECRET="$READER_TOKEN_SECRET"
  info "使用你通过环境变量提供的 READER_TOKEN_SECRET"
else
  # 生成 48 字节随机密钥
  if command -v openssl >/dev/null 2>&1; then
    TOKEN_SECRET="$(openssl rand -base64 48 | tr -d '\n/+=' | cut -c1-48)"
  else
    TOKEN_SECRET="$(head -c 64 /dev/urandom | base64 | tr -d '\n/+=' | cut -c1-48)"
  fi
  ok "已生成 48 位随机密钥"
fi

# ---------------------------- 3. 静态 IP -------------------------------------
info "步骤 3/7：预留固定公网 IP（避免重启后地址变化）..."
if gcloud compute addresses describe "$STATIC_IP_NAME" --region "$REGION" --project "$PROJECT" >/dev/null 2>&1; then
  info "固定 IP 已存在，复用"
else
  gcloud compute addresses create "$STATIC_IP_NAME" --region "$REGION" --project "$PROJECT" >/dev/null
  ok "已创建固定 IP"
fi
STATIC_IP="$(gcloud compute addresses describe "$STATIC_IP_NAME" --region "$REGION" --project "$PROJECT" --format='get(address)')"
ok "公网 IP：$STATIC_IP"

# ---------------------------- 4. 防火墙 --------------------------------------
info "步骤 4/7：配置防火墙（开放 80 端口）..."
if gcloud compute firewall-rules describe "$FIREWALL_RULE" --project "$PROJECT" >/dev/null 2>&1; then
  info "防火墙规则已存在，复用"
else
  gcloud compute firewall-rules create "$FIREWALL_RULE" \
    --project "$PROJECT" \
    --allow tcp:80 \
    --target-tags reader-server \
    --description "Allow HTTP access to the reader book server" >/dev/null
  ok "已创建防火墙规则"
fi

# ---------------------------- 5. 数据盘 --------------------------------------
info "步骤 5/7：创建 ${DISK_SIZE_GB}GB 永久数据盘..."
if gcloud compute disks describe "$DISK_NAME" --zone "$ZONE" --project "$PROJECT" >/dev/null 2>&1; then
  info "数据盘已存在，复用（不会清空数据）"
else
  gcloud compute disks create "$DISK_NAME" \
    --project "$PROJECT" \
    --zone "$ZONE" \
    --size "${DISK_SIZE_GB}GB" \
    --type pd-standard >/dev/null
  ok "已创建数据盘"
fi

# ---------------------------- 6. 渲染 cloud-init -----------------------------
info "步骤 6/7：生成启动脚本..."
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_INIT_SRC="$HERE/cloud-init.yaml"
[ -f "$CLOUD_INIT_SRC" ] || die "找不到 cloud-init.yaml（应与本脚本在同一目录）"

TMP_INIT="$(mktemp)"
trap 'rm -f "$TMP_INIT"' EXIT

# 用实际值替换占位符
# 注意：用 | 作分隔符，避免密钥里的 / 造成问题
sed -e "s|__TOKEN_SECRET__|${TOKEN_SECRET}|g" \
    -e "s|__INVITE_CODE__|${INVITE_CODE}|g" \
    -e "s|__ALLOW_REGISTRATION__|${ALLOW_REGISTRATION}|g" \
    -e "s|__IMAGE__|${IMAGE}|g" \
    "$CLOUD_INIT_SRC" > "$TMP_INIT"

ok "启动脚本已生成"

# ---------------------------- 7. 创建虚拟机 ----------------------------------
info "步骤 7/7：创建虚拟机（约需 1-2 分钟）..."
if gcloud compute instances describe "$VM_NAME" --zone "$ZONE" --project "$PROJECT" >/dev/null 2>&1; then
  warn "虚拟机 $VM_NAME 已存在。"
  echo
  echo "如果你想重新部署（会重置启动脚本），请先删除："
  echo "  gcloud compute instances delete $VM_NAME --zone $ZONE --keep-disks=boot"
  echo
  echo "如果只是想看状态，运行："
  echo "  gcloud compute ssh $VM_NAME --zone $ZONE --command 'sudo systemctl status reader'"
  exit 0
fi

gcloud compute instances create "$VM_NAME" \
  --project "$PROJECT" \
  --zone "$ZONE" \
  --machine-type "$MACHINE_TYPE" \
  --image-family debian-12 \
  --image-project debian-cloud \
  --boot-disk-size 10GB \
  --boot-disk-type pd-standard \
  --tags reader-server \
  --address "$STATIC_IP" \
  --disk "name=$DISK_NAME,device-name=reader-data,mode=rw,boot=no" \
  --metadata-from-file user-data="$TMP_INIT" \
  --scopes cloud-platform \
  >/dev/null

ok "虚拟机已创建"

# ---------------------------- 完成 -------------------------------------------
echo
echo "=============================================================="
echo "${GRN}  部署完成！${NC}"
echo "=============================================================="
echo
echo "  ${GRN}访问地址：http://${STATIC_IP}/${NC}"
echo
echo "  管理密钥（请妥善保存，登录管理后台需要）："
echo "  ${YLW}${TOKEN_SECRET}${NC}"
echo
echo "=============================================================="
echo
echo "首次访问说明："
echo "  1. 打开上面的地址"
echo "  2. 系统会提示初始化，第一个注册的账号自动成为【管理员】"
echo "  3. 管理员账号：自己填用户名和密码"
if [ -n "$INVITE_CODE" ]; then
  echo "  4. 其他人注册需要邀请码：${YLW}${INVITE_CODE}${NC}"
else
  echo "  4. 注册已关闭，只有你（第一个账号）可以使用"
fi
echo
echo "⚠️  服务需要 1-2 分钟完成 Docker 安装，如果打不开请稍等再刷新。"
echo
echo "常用管理命令（通过 SSH）："
echo "  gcloud compute ssh $VM_NAME --zone $ZONE"
echo "  sudo systemctl status reader     # 查看状态"
echo "  sudo journalctl -u reader -f     # 实时日志"
echo "  sudo systemctl restart reader    # 重启服务"
echo
echo "查看初始化进度："
echo "  gcloud compute ssh $VM_NAME --zone $ZONE --command 'sudo tail -f /var/log/reader-bootstrap.log'"
echo
