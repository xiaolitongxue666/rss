#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 从 cookie/weibo_cookies.py 或 cookie/weibo.txt 生成 WEIBO_COOKIES 并合并到 .env，
# 可选应用到本地或远程服务器，并重启 rsshub 容器。
# 用法（在 rss 项目根目录执行）：
#   ./scripts/apply-weibo-cookie.sh              # 合并到本地 .env 并重启 rsshub
#   ./scripts/apply-weibo-cookie.sh --remote     # 合并到远程服务器 .env 并重启 rsshub
#   ./scripts/apply-weibo-cookie.sh --no-restart # 仅合并到 .env，不重启
# 可选环境变量（--remote 时）：REMOTE_USER、REMOTE_HOST、REMOTE_ALCHEMY_DIR（与 stack-upload-to-server.sh 一致）
# ---------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RSS_ROOT"

REMOTE_USER="${REMOTE_USER:-leonli}"
REMOTE_HOST="${REMOTE_HOST:-moicen.com}"
REMOTE_ALCHEMY_DIR="${REMOTE_ALCHEMY_DIR:-/home/alchemy/RSS}"
REMOTE_RSS_ROOT="${REMOTE_RSS_ROOT:-${REMOTE_ALCHEMY_DIR}/rss}"
ENV_FILE="$RSS_ROOT/.env"
COOKIE_SOURCE="py"
APPLY_LOCAL="1"
DO_RESTART="1"

while [ $# -gt 0 ]; do
  case "$1" in
    --source)
      COOKIE_SOURCE="$2"
      shift 2
      ;;
    --remote)
      APPLY_LOCAL="0"
      shift
      ;;
    --local)
      APPLY_LOCAL="1"
      shift
      ;;
    --no-restart)
      DO_RESTART="0"
      shift
      ;;
    *)
      echo "未知选项: $1" >&2
      exit 1
      ;;
  esac
done

# 生成 WEIBO_COOKIES= 行（不向终端输出 Cookie 内容）
ENV_LINE="$("$SCRIPT_DIR/cookie-to-env.py" --site weibo --source "$COOKIE_SOURCE" 2>/dev/null)"
if [ -z "$ENV_LINE" ]; then
  echo "错误：无法从 cookie 目录生成微博 Cookie 行，请确认 cookie/weibo_cookies.py 或 cookie/weibo.txt 存在且格式正确"
  exit 1
fi

if [ "$APPLY_LOCAL" = "1" ]; then
  # ---------- 本地：合并到 .env ----------
  if [ ! -f "$ENV_FILE" ]; then
    if [ -f .env.stack.example ]; then
      cp .env.stack.example "$ENV_FILE"
      echo "已从 .env.stack.example 创建 .env"
    else
      echo "错误：缺少 .env.stack.example，无法创建 .env"
      exit 1
    fi
  fi
  if grep -q "^WEIBO_COOKIES=" "$ENV_FILE" 2>/dev/null; then
    sed -i.bak '/^WEIBO_COOKIES=/d' "$ENV_FILE"
  fi
  echo "$ENV_LINE" >> "$ENV_FILE"
  echo "已合并 WEIBO_COOKIES 到本地 .env（未显示 Cookie 内容）。"

  if [ "$DO_RESTART" = "1" ]; then
    echo "重启 rsshub 容器..."
    docker compose -f docker-compose.stack.yml up -d rsshub
    echo "rsshub 已重启，微博 Cookie 已生效。"
  else
    echo "未重启 rsshub；需生效请执行: docker compose -f docker-compose.stack.yml up -d rsshub"
  fi
else
  # ---------- 远程：上传到用户家目录，再 sudo 拷到 REMOTE_ALCHEMY_DIR，以 alchemy 合并并重启 ----------
  FRAGMENT_FILE="$RSS_ROOT/.env.weibo.cookie.$$"
  echo "$ENV_LINE" > "$FRAGMENT_FILE"
  trap 'rm -f "$FRAGMENT_FILE"' EXIT

  echo "=== 上传微博 Cookie 片段到 ${REMOTE_USER}@${REMOTE_HOST} (~/) ==="
  scp "$FRAGMENT_FILE" "${REMOTE_USER}@${REMOTE_HOST}:~/.env.weibo.cookie"

  echo "=== 在服务器上拷贝到 ${REMOTE_RSS_ROOT}、合并 .env 并重启 rsshub ==="
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "sudo cp ~/.env.weibo.cookie ${REMOTE_RSS_ROOT}/.env.weibo.cookie && sudo chown alchemy:alchemy ${REMOTE_RSS_ROOT}/.env.weibo.cookie && sudo -u alchemy bash -c 'cd ${REMOTE_RSS_ROOT} && sed -i.bak \"/^WEIBO_COOKIES=/d\" .env 2>/dev/null; cat .env.weibo.cookie >> .env; rm -f .env.weibo.cookie; docker compose -f docker-compose.stack.yml up -d rsshub'"

  echo "远程 .env 已更新并已重启 rsshub。"
fi
