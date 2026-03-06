#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 将本地 cookie/ 目录下的配置文件 scp 到服务器正确位置，合并到服务器 .env 并重启 rsshub。
# 不通过脚本“登录服务器”（仅用 scp/ssh 执行上传与合并）；步骤 1 需在本地终端先 push、再在服务器上 pull。
# 用法（在 rss 项目根目录执行）：
#   ./scripts/upload-cookie-and-apply-remote.sh
# 环境变量：REMOTE_USER、REMOTE_HOST、REMOTE_ALCHEMY_DIR（同 stack-upload-to-server.sh）
# 从本地 .env 读取已配置的 BILIBILI_COOKIE_<uid> 的 uid，对每个 uid 用 cookie/ 生成并合并；微博用 cookie/weibo_* 生成 WEIBO_COOKIES。
# ---------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RSS_ROOT"

REMOTE_USER="${REMOTE_USER:-leonli}"
REMOTE_HOST="${REMOTE_HOST:-moicen.com}"
REMOTE_ALCHEMY_DIR="${REMOTE_ALCHEMY_DIR:-/home/alchemy/RSS}"
REMOTE_RSS_ROOT="${REMOTE_RSS_ROOT:-${REMOTE_ALCHEMY_DIR}/rss}"
COOKIE_DIR="$RSS_ROOT/cookie"
ENV_FILE="$RSS_ROOT/.env"

# 1) 上传 cookie 目录到服务器（仅 .py / .txt，避免 .gitignore 等）
UPLOAD_TMP="$RSS_ROOT/.cookie_upload_$$"
FRAGMENT_FILE="$RSS_ROOT/.env.cookie.frag.$$"
trap 'rm -rf "$UPLOAD_TMP"; rm -f "$FRAGMENT_FILE"' EXIT

mkdir -p "$UPLOAD_TMP"
for f in "$COOKIE_DIR"/*.py "$COOKIE_DIR"/*.txt; do
  [ -f "$f" ] && cp "$f" "$UPLOAD_TMP/"
done
if [ -z "$(ls -A "$UPLOAD_TMP" 2>/dev/null)" ]; then
  echo "cookie/ 下无 .py 或 .txt 文件，跳过上传 cookie 目录。"
else
  echo "=== 上传 cookie/* 到 ${REMOTE_USER}@${REMOTE_HOST} 并放到 ${REMOTE_RSS_ROOT}/cookie/ ==="
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ~/.cookie_upload"
  scp -r "$UPLOAD_TMP"/* "${REMOTE_USER}@${REMOTE_HOST}:~/.cookie_upload/"
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "sudo mkdir -p ${REMOTE_RSS_ROOT}/cookie && sudo cp -f ~/.cookie_upload/* ${REMOTE_RSS_ROOT}/cookie/ 2>/dev/null; sudo chown -R alchemy:alchemy ${REMOTE_RSS_ROOT}/cookie; rm -rf ~/.cookie_upload"
fi

# 2) 生成 .env 片段（微博 + 本机 .env 中已有的 B 站 uid），合并为一个文件
: > "$FRAGMENT_FILE"

if [ -f "$ENV_FILE" ]; then
  BILIBILI_UIDS=$(grep -oE 'BILIBILI_COOKIE_[0-9]+=' "$ENV_FILE" 2>/dev/null | sed 's/BILIBILI_COOKIE_\([0-9]*\)=/\1/' | sort -u)
else
  BILIBILI_UIDS=""
fi

SED_REMOVE=""

# 微博
if [ -f "$COOKIE_DIR/weibo_cookies.py" ] || [ -f "$COOKIE_DIR/weibo.txt" ]; then
  ENV_LINE="$("$SCRIPT_DIR/cookie-to-env.py" --site weibo --source py 2>/dev/null)" || ENV_LINE="$("$SCRIPT_DIR/cookie-to-env.py" --site weibo --source txt 2>/dev/null)" || true
  if [ -n "$ENV_LINE" ]; then
    echo "$ENV_LINE" >> "$FRAGMENT_FILE"
    SED_REMOVE="${SED_REMOVE} -e \"/^WEIBO_COOKIES=/d\""
  fi
fi

# B 站（按本机 .env 中已有 uid）
for uid in $BILIBILI_UIDS; do
  ENV_LINE="$("$SCRIPT_DIR/cookie-to-env.py" --site bilibili --uid "$uid" --source py 2>/dev/null)" || ENV_LINE="$("$SCRIPT_DIR/cookie-to-env.py" --site bilibili --uid "$uid" --source txt 2>/dev/null)" || true
  if [ -n "$ENV_LINE" ]; then
    echo "$ENV_LINE" >> "$FRAGMENT_FILE"
    SED_REMOVE="${SED_REMOVE} -e \"/^BILIBILI_COOKIE_${uid}=/d\""
  fi
done

# 3) 若有片段则上传并在服务器上合并、重启 rsshub
if [ -s "$FRAGMENT_FILE" ]; then
  echo "=== 上传 .env 片段到服务器并合并、重启 rsshub ==="
  scp "$FRAGMENT_FILE" "${REMOTE_USER}@${REMOTE_HOST}:~/.env.cookie.frag"
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "sudo cp ~/.env.cookie.frag ${REMOTE_RSS_ROOT}/.env.cookie.frag && sudo chown alchemy:alchemy ${REMOTE_RSS_ROOT}/.env.cookie.frag && sudo -u alchemy bash -c 'cd ${REMOTE_RSS_ROOT} && sed -i.bak ${SED_REMOVE} .env 2>/dev/null; cat .env.cookie.frag >> .env; rm -f .env.cookie.frag; docker compose -f docker-compose.stack.yml up -d rsshub; docker compose -f docker-compose.stack.yml exec -T redis redis-cli DEL weibo:friends:login-user weibo:user:index:undefined 2>/dev/null || true'"
  echo "cookie 已上传、.env 已合并、rsshub 已重启，并已清理微博相关 Redis 缓存。"
else
  echo "未生成任何 Cookie 片段（无 weibo cookie 且本机 .env 无 BILIBILI_COOKIE_*），未修改服务器 .env。"
fi
