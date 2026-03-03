#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 将 B 站 Cookie 安全追加到项目根目录 .env（不向终端或日志输出 Cookie）
# 用法：在 rss 项目根目录执行 ./scripts/add-bilibili-cookie.sh
# 详见 docs/bilibili-cookie-docker.md
# ---------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RSS_ROOT"

ENV_FILE="$RSS_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
  if [ -f .env.stack.example ]; then
    cp .env.stack.example "$ENV_FILE"
    echo "已从 .env.stack.example 创建 .env"
  else
    echo "错误：缺少 .env.stack.example，无法创建 .env"
    exit 1
  fi
fi

echo "请输入 B 站用户 uid（纯数字，与订阅路由中的 uid 一致）："
read -r UID
if ! [[ "$UID" =~ ^[0-9]+$ ]]; then
  echo "错误：uid 必须为数字"
  exit 1
fi

echo "请粘贴 Cookie（输入时不会回显），粘贴完成后按 Enter："
read -rs COOKIE
echo ""
if [ -z "$COOKIE" ]; then
  echo "错误：Cookie 为空"
  exit 1
fi

# 若 Cookie 内含双引号，转义为 \"
COOKIE_ESCAPED="${COOKIE//\"/\\\"}"
# 若转义后与原文长度不同，说明含双引号，提示用户可手动核对
if [ "${#COOKIE_ESCAPED}" -ne "${#COOKIE}" ]; then
  echo "提示：Cookie 内含双引号，已做转义；若后续生效异常可打开 .env 手动核对。"
fi

LINE="BILIBILI_COOKIE_${UID}=\"${COOKIE_ESCAPED}\""
echo "$LINE" >> "$ENV_FILE"
echo "已追加 BILIBILI_COOKIE_${UID} 到 .env（未显示 Cookie 内容）。请执行以下命令使 rsshub 生效："
echo "  docker compose -f docker-compose.stack.yml up -d rsshub"
