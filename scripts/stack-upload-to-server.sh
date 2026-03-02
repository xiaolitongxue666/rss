#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# RSS + Clash 栈：在本地打包栈镜像（输出到 rss 项目内）并上传到服务器、在服务器上 load
# 依赖：已配置 .env、可 ssh/scp 到 REMOTE_HOST
# 用法：在 rss 项目根目录执行 ./scripts/stack-upload-to-server.sh
# 可选环境变量：REMOTE_USER、REMOTE_HOST、REMOTE_ALCHEMY_DIR、SKIP_PACK=1（仅上传已有 tar）
# ---------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RSS_ROOT"

REMOTE_USER="${REMOTE_USER:-leonli}"
REMOTE_HOST="${REMOTE_HOST:-moicen.com}"
REMOTE_ALCHEMY_DIR="${REMOTE_ALCHEMY_DIR:-/home/alchemy/RSS}"
TAR_FILE="${RSS_ROOT}/rss-stack-images.tar"

if [ "${SKIP_PACK}" != "1" ]; then
  echo "=== 1. 打包栈镜像（输出到项目内 rss-stack-images.tar）==="
  export STACK_IMAGES_TAR="$TAR_FILE"
  "$SCRIPT_DIR/stack-images-pack.sh"
else
  if [ ! -f "$TAR_FILE" ]; then
    echo "错误：SKIP_PACK=1 但不存在 $TAR_FILE，请先执行 ./scripts/stack-images-pack.sh"
    exit 1
  fi
  echo "跳过打包，使用已有 $TAR_FILE"
fi

echo ""
echo "=== 2. 上传到服务器（先传到 ${REMOTE_USER} 家目录再移到 alchemy）==="
scp "$TAR_FILE" "${REMOTE_USER}@${REMOTE_HOST}:~/rss-stack-images.tar"

echo ""
echo "=== 3. 在服务器上移动到 ${REMOTE_ALCHEMY_DIR} 并 load ==="
ssh "${REMOTE_USER}@${REMOTE_HOST}" "sudo mv /home/${REMOTE_USER}/rss-stack-images.tar ${REMOTE_ALCHEMY_DIR}/ && sudo chown alchemy:alchemy ${REMOTE_ALCHEMY_DIR}/rss-stack-images.tar && sudo -u alchemy docker load -i ${REMOTE_ALCHEMY_DIR}/rss-stack-images.tar"

echo ""
echo "完成。服务器上进入 ${REMOTE_ALCHEMY_DIR}/rss 后：更新后一键部署请先 git pull 再执行 ./scripts/stack-server-update-and-start.sh；仅启动栈可执行 ./scripts/stack-build-and-up.sh。"
