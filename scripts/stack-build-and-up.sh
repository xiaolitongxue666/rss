#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# RSS + Clash 栈：一键构建并启动
# 依赖：Docker、已复制 .env.stack.example 为 .env 并填写 CLASH_AIO_PATH、RAW_SUB_URL
# 用法：在 rss 项目根目录执行 ./scripts/stack-build-and-up.sh
# ---------------------------------------------------------------------------

set -e

# ---------- 进入 rss 项目根目录 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RSS_ROOT"

# ---------- 构建前环境检查（可 SKIP_PRE_INSTALL=1 跳过） ----------
"$SCRIPT_DIR/stack-pre-install.sh" || true

# ---------- 加载 .env 并确定 CLASH_AIO_PATH、BUILD_PROXY ----------
CLASH_AIO_PATH="${CLASH_AIO_PATH:-./clash-aio}"
if [ -f .env ]; then
  set -a
  # shellcheck source=/dev/null
  source .env 2>/dev/null || true
  set +a
  [ -n "${CLASH_AIO_PATH}" ] || CLASH_AIO_PATH="./clash-aio"
fi
# 构建时代理：.env 中设置 BUILD_PROXY=http://host.docker.internal:7890 可加速拉包（需本机已起代理）；Linux 可用 BUILD_PROXY=http://<本机IP>:7890
[ -n "${BUILD_PROXY}" ] && export BUILD_PROXY
# 转为绝对路径便于 compose 使用
if [ ! -d "$CLASH_AIO_PATH" ]; then
  CLASH_AIO_PATH="$RSS_ROOT/$CLASH_AIO_PATH"
fi
if [ ! -d "$CLASH_AIO_PATH" ]; then
  echo "错误：CLASH_AIO_PATH 指向的目录不存在: $CLASH_AIO_PATH"
  echo "请设置 CLASH_AIO_PATH（或在 .env 中），或执行 git submodule update --init clash-aio 后使用默认 ./clash-aio"
  exit 1
fi
CLASH_AIO_PATH="$(cd "$CLASH_AIO_PATH" && pwd)"
export CLASH_AIO_PATH

# ---------- 检查 clash-aio 必要文件 ----------
if [ ! -f "$CLASH_AIO_PATH/Dockerfile" ] || [ ! -f "$CLASH_AIO_PATH/preprocess.sh" ]; then
  echo "错误：$CLASH_AIO_PATH 中缺少 Dockerfile 或 preprocess.sh"
  exit 1
fi

# ---------- 可选：检查 .env 中 RAW_SUB_URL ----------
if [ -f .env ] && ! grep -q '^RAW_SUB_URL=.\+' .env 2>/dev/null; then
  echo "提示：.env 中 RAW_SUB_URL 似乎未填写，clash-with-ui 可能无法拉取订阅"
  read -r -p "是否继续？ [y/N] " cont
  case "${cont:-N}" in
    [yY]) ;;
    *) exit 0 ;;
  esac
fi

# ---------- 构建镜像 ----------
echo "使用 CLASH_AIO_PATH=$CLASH_AIO_PATH"
echo "构建栈镜像（subconverter 使用上游镜像，clash-with-ui、rsshub 本地构建）..."
docker compose -f docker-compose.stack.yml build 2>/dev/null || docker-compose -f docker-compose.stack.yml build

# ---------- 启动栈 ----------
echo "启动容器..."
docker compose -f docker-compose.stack.yml up -d 2>/dev/null || docker compose -f docker-compose.stack.yml up -d

# ---------- 可选：等待 rsshub 就绪并验证 ----------
echo "等待 rsshub 端口 1200 就绪..."
for i in $(seq 1 30); do
  if curl -sf -o /dev/null "http://127.0.0.1:1200/" 2>/dev/null; then
    echo "RSSHub 已就绪: http://127.0.0.1:1200/"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "超时未检测到 1200 端口，请检查: docker logs rss-stack-rsshub 或 docker compose -f docker-compose.stack.yml logs"
    exit 1
  fi
  sleep 2
done

echo "栈已启动。RSS 地址: http://127.0.0.1:1200/"
