#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# RSS + Clash 栈：服务器端「更新后一键启动」流程
# 顺序：检查 Docker 权限 → 加载上传的镜像 tar（若存在）→ 停止旧容器 → 启动栈
# 用法：在 rss 项目根目录执行 ./scripts/stack-server-update-and-start.sh
# 可选：STACK_IMAGES_TAR 指定 tar 路径，未设时尝试 ../rss-stack-images.tar 与 /tmp/rss-stack-images.tar
# ---------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RSS_ROOT"

echo "========== 1. 检查 Docker 权限 =========="
if ! docker ps >/dev/null 2>&1; then
  echo "错误：当前用户无 Docker 权限（docker ps 失败）。请让管理员执行 usermod -aG docker <用户> 后重新登录。"
  exit 1
fi
echo "Docker 权限正常。"

echo ""
echo "========== 2. 加载镜像（若存在 tar）=========="
TAR_PATH="${STACK_IMAGES_TAR}"
if [ -z "$TAR_PATH" ]; then
  for candidate in "$RSS_ROOT/../rss-stack-images.tar" "/home/alchemy/RSS/rss-stack-images.tar" "/tmp/rss-stack-images.tar"; do
    if [ -f "$candidate" ]; then
      TAR_PATH="$candidate"
      break
    fi
  done
fi
if [ -n "$TAR_PATH" ] && [ -f "$TAR_PATH" ]; then
  echo "从 $TAR_PATH 加载镜像..."
  docker load -i "$TAR_PATH"
  echo "镜像加载完成。"
else
  echo "未找到镜像 tar（可设置 STACK_IMAGES_TAR），跳过加载；若已加载过镜像则直接进入下一步。"
fi

echo ""
echo "========== 3. 停止旧容器 =========="
"$SCRIPT_DIR/stack-down.sh" || true

echo ""
echo "========== 4. 启动栈 =========="
"$SCRIPT_DIR/stack-build-and-up.sh"
