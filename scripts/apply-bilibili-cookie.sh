#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 从 cookie/bilibili_cookies.py 或 cookie/bilibili.txt 生成 BILIBILI_COOKIE_<uid> 并合并到 .env，
# 可选应用到本地或远程服务器，并重启 rsshub 容器。
# 用法（在 rss 项目根目录执行）：
#   ./scripts/apply-bilibili-cookie.sh              # 交互输入 uid，合并到本地 .env 并重启 rsshub
#   ./scripts/apply-bilibili-cookie.sh --uid 2267573
#   ./scripts/apply-bilibili-cookie.sh --remote     # 合并到远程服务器 .env 并重启 rsshub
#   ./scripts/apply-bilibili-cookie.sh --no-restart # 仅合并到 .env，不重启
# 可选环境变量（--remote 时）：REMOTE_USER、REMOTE_HOST、REMOTE_ALCHEMY_DIR（与 stack-upload-to-server.sh 一致）
# ---------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RSS_ROOT"

REMOTE_USER="${REMOTE_USER:-leonli}"
REMOTE_HOST="${REMOTE_HOST:-moicen.com}"
REMOTE_ALCHEMY_DIR="${REMOTE_ALCHEMY_DIR:-/home/alchemy/RSS}"
# 服务器上 rss 项目根目录（.env 与 docker-compose.stack.yml 所在处）
REMOTE_RSS_ROOT="${REMOTE_RSS_ROOT:-${REMOTE_ALCHEMY_DIR}/rss}"
ENV_FILE="$RSS_ROOT/.env"
COOKIE_SOURCE="py"
APPLY_LOCAL="1"
DO_RESTART="1"

while [ $# -gt 0 ]; do
  case "$1" in
    --uid)
      BILIBILI_UID="$2"
      shift 2
      ;;
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

if [ -z "${BILIBILI_UID:-}" ]; then
  echo "请输入 B 站用户 uid（纯数字，与订阅路由中的 uid 一致）："
  read -r BILIBILI_UID
fi
if ! [[ "${BILIBILI_UID:-}" =~ ^[0-9]+$ ]]; then
  echo "错误：uid 必须为数字"
  exit 1
fi

# 生成 BILIBILI_COOKIE_<uid>= 行（不向终端输出 Cookie 内容）
ENV_LINE="$("$SCRIPT_DIR/cookie-to-env.py" --uid "$BILIBILI_UID" --source "$COOKIE_SOURCE" 2>/dev/null)"
if [ -z "$ENV_LINE" ]; then
  echo "错误：无法从 cookie 目录生成 Cookie 行，请确认 cookie/bilibili_cookies.py 或 cookie/bilibili.txt 存在且格式正确"
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
  # 仅删除本 uid 的旧行，再追加（保留其他 uid 的多账号配置）
  if grep -q "^BILIBILI_COOKIE_${BILIBILI_UID}=" "$ENV_FILE" 2>/dev/null; then
    sed -i.bak "/^BILIBILI_COOKIE_${BILIBILI_UID}=/d" "$ENV_FILE"
  fi
  echo "$ENV_LINE" >> "$ENV_FILE"
  echo "已合并 BILIBILI_COOKIE_${BILIBILI_UID} 到本地 .env（未显示 Cookie 内容）。"

  if [ "$DO_RESTART" = "1" ]; then
    echo "重启 rsshub 容器..."
    docker compose -f docker-compose.stack.yml up -d rsshub
    echo "rsshub 已重启，Cookie 已生效。"
  else
    echo "未重启 rsshub；需生效请执行: docker compose -f docker-compose.stack.yml up -d rsshub"
  fi
else
  # ---------- 远程：上传到用户家目录，再 sudo 拷到 REMOTE_ALCHEMY_DIR，以 alchemy 合并并重启 ----------
  FRAGMENT_FILE="$RSS_ROOT/.env.bilibili.cookie.$$"
  echo "$ENV_LINE" > "$FRAGMENT_FILE"
  trap 'rm -f "$FRAGMENT_FILE"' EXIT

  echo "=== 上传 Cookie 片段到 ${REMOTE_USER}@${REMOTE_HOST} (~/) ==="
  scp "$FRAGMENT_FILE" "${REMOTE_USER}@${REMOTE_HOST}:~/.env.bilibili.cookie"

  echo "=== 在服务器上拷贝到 ${REMOTE_RSS_ROOT}、合并 .env 并重启 rsshub ==="
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "sudo cp ~/.env.bilibili.cookie ${REMOTE_RSS_ROOT}/.env.bilibili.cookie && sudo chown alchemy:alchemy ${REMOTE_RSS_ROOT}/.env.bilibili.cookie && sudo -u alchemy bash -c 'cd ${REMOTE_RSS_ROOT} && sed -i.bak \"/^BILIBILI_COOKIE_${BILIBILI_UID}=/d\" .env 2>/dev/null; cat .env.bilibili.cookie >> .env; rm -f .env.bilibili.cookie; docker compose -f docker-compose.stack.yml up -d rsshub'"

  echo "远程 .env 已更新并已重启 rsshub。"
fi
