#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# RSS + Clash 栈：从零构建并分步启动（系统性测试入口）
# 流程：停止全部 → 前置检查 clash-aio → 构建 → 先启动 Clash → 再启动 RSS → 整体验证
# 用法：在 rss 项目根目录执行 ./scripts/stack-from-zero.sh
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

# ---------- 1. 停止所有相关容器 ----------
echo "========== 1. 停止所有相关容器 =========="
"$SCRIPT_DIR/stack-stop-all.sh"

# ---------- 2. 前置检查（clash-aio 是否存在等） ----------
echo "========== 2. 前置检查 clash-aio =========="
"$SCRIPT_DIR/stack-pre-install.sh" || true

# ---------- 加载 .env 并校验 CLASH_AIO_PATH ----------
CLASH_AIO_PATH="${CLASH_AIO_PATH:-./clash-aio}"
if [ -f .env ]; then
  set -a
  # shellcheck source=/dev/null
  source .env 2>/dev/null || true
  set +a
  [ -n "${CLASH_AIO_PATH}" ] || CLASH_AIO_PATH="./clash-aio"
fi
if [ ! -d "$CLASH_AIO_PATH" ]; then
  CLASH_AIO_PATH="$RSS_ROOT/$CLASH_AIO_PATH"
fi
if [ ! -d "$CLASH_AIO_PATH" ]; then
  echo "错误：CLASH_AIO_PATH 指向的目录不存在: $CLASH_AIO_PATH"
  exit 1
fi
CLASH_AIO_PATH="$(cd "$CLASH_AIO_PATH" && pwd)"
export CLASH_AIO_PATH

if [ ! -f "$CLASH_AIO_PATH/Dockerfile" ] || [ ! -f "$CLASH_AIO_PATH/preprocess.sh" ]; then
  echo "错误：$CLASH_AIO_PATH 中缺少 Dockerfile 或 preprocess.sh"
  exit 1
fi

if [ -f .env ] && ! grep -q '^RAW_SUB_URL=.\+' .env 2>/dev/null; then
  echo "提示：.env 中 RAW_SUB_URL 似乎未填写，clash-with-ui 可能无法拉取订阅"
  read -r -p "是否继续？ [y/N] " cont
  case "${cont:-N}" in
    [yY]) ;;
    *) exit 0 ;;
  esac
fi

# ---------- 3. 构建 ----------
echo "========== 3. 构建栈镜像 =========="
[ -n "${BUILD_PROXY}" ] && export BUILD_PROXY
$COMPOSE_CMD -f docker-compose.stack.yml build

# ---------- 4. 先启动 Clash 相关（subconverter + clash-with-ui） ----------
echo "========== 4. 启动 Clash 相关服务 =========="
$COMPOSE_CMD -f docker-compose.stack.yml up -d subconverter clash-with-ui

echo "等待 Subconverter 25501 就绪..."
for i in $(seq 1 30); do
  if curl -s -o /dev/null --connect-timeout 2 --max-time 5 "http://127.0.0.1:25501/" 2>/dev/null; then
    echo "Subconverter 已就绪: http://127.0.0.1:25501/"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "超时未检测到 25501 端口，请检查 stack 日志"
    exit 1
  fi
  sleep 2
done

echo "等待 Clash 容器就绪..."
sleep 5
for i in $(seq 1 20); do
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'rss-stack-clash-with-ui'; then
    echo "Clash 容器已运行"
    break
  fi
  if [ "$i" -eq 20 ]; then
    echo "告警: 未在预期时间内看到 clash-with-ui 容器，继续启动 RSS 部分"
  fi
  sleep 2
done

# ---------- 5. 再启动 RSS 相关（redis + rsshub） ----------
echo "========== 5. 启动 RSS 相关服务 =========="
$COMPOSE_CMD -f docker-compose.stack.yml up -d redis rsshub

echo "等待 RSSHub 1200 就绪..."
for i in $(seq 1 30); do
  if curl -sf -o /dev/null "http://127.0.0.1:1200/" 2>/dev/null; then
    echo "RSSHub 已就绪: http://127.0.0.1:1200/"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "超时未检测到 1200 端口，请检查: docker logs rss-stack-rsshub"
    exit 1
  fi
  sleep 2
done

# ---------- 6. 整体验证 ----------
echo "========== 6. 整体验证 =========="
if "$SCRIPT_DIR/stack-verify.sh"; then
  echo "系统性测试通过，整体已正常工作。"
else
  echo "整体验证未通过。"
  exit 1
fi
