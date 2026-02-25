#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# RSS + Clash 栈：在服务器上从 tar 加载栈镜像（用于离线部署）
# 默认读取 /tmp/rss-stack-images.tar，可通过环境变量 STACK_IMAGES_TAR 覆盖
# 用法：在 rss 项目根目录执行 ./scripts/stack-images-load.sh
# ---------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RSS_ROOT"

TAR_PATH="${STACK_IMAGES_TAR:-/tmp/rss-stack-images.tar}"
if [ ! -f "$TAR_PATH" ]; then
  echo "错误：镜像包不存在: $TAR_PATH"
  echo "请先将本机生成的 rss-stack-images.tar 上传到服务器（如 /tmp/），或设置 STACK_IMAGES_TAR 指向该文件。"
  exit 1
fi

echo "从 $TAR_PATH 加载镜像..."
docker load -i "$TAR_PATH"
echo "加载完成。可执行 ./scripts/stack-build-and-up.sh 启动栈。"
