#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# RSS + Clash 栈：停止所有相关容器（stack、默认 compose、独立 clash-aio compose）
# 用于系统性测试前清空环境，或日常停止全部服务
# 用法：在 rss 项目根目录执行 ./scripts/stack-stop-all.sh
# ---------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RSS_ROOT"

# ---------- 检测 Docker Compose V2（仅支持 docker compose，不支持已废弃的 docker-compose） ----------
COMPOSE_CMD="docker compose"
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  echo "错误：未检测到 Docker 或 Docker Compose V2（docker compose）。请安装 Docker 并启用 Compose 插件。"
  exit 1
fi

is_valid_clash_dir() {
  [ -d "$1" ] && [ -f "$1/Dockerfile" ] && [ -f "$1/preprocess.sh" ]
}

# ---------- 停止 stack 栈 ----------
echo "停止 stack 栈 (docker-compose.stack.yml)..."
$COMPOSE_CMD -f docker-compose.stack.yml down 2>/dev/null || true

# ---------- 停止默认 rss compose ----------
echo "停止默认 compose (docker-compose.yml)..."
$COMPOSE_CMD down 2>/dev/null || true

# ---------- 解析 clash-aio 路径并停止其独立 compose ----------
CLASH_AIO_DIR=""
if [ -f .env ]; then
  CLASH_AIO_PATH=$(grep -E '^CLASH_AIO_PATH=' .env 2>/dev/null | cut -d= -f2- | sed 's/^[" ]*//;s/[" ]*$//' || true)
  if [ -n "$CLASH_AIO_PATH" ]; then
    [ ! -d "$CLASH_AIO_PATH" ] && CLASH_AIO_PATH="$RSS_ROOT/$CLASH_AIO_PATH"
    is_valid_clash_dir "$CLASH_AIO_PATH" && CLASH_AIO_DIR="$CLASH_AIO_PATH"
  fi
fi
if [ -z "$CLASH_AIO_DIR" ]; then
  for candidate in "$RSS_ROOT/clash-aio" "$RSS_ROOT/../clash-aio" "$RSS_ROOT/../../Proxy/clash-aio"; do
    if is_valid_clash_dir "$candidate"; then
      CLASH_AIO_DIR="$candidate"
      break
    fi
  done
fi

if [ -n "$CLASH_AIO_DIR" ] && [ -f "$CLASH_AIO_DIR/docker-compose.yaml" ]; then
  echo "停止独立 clash-aio compose: $CLASH_AIO_DIR"
  (cd "$CLASH_AIO_DIR" && $COMPOSE_CMD -f docker-compose.yaml down 2>/dev/null) || true
fi

echo "所有相关容器已停止。"
