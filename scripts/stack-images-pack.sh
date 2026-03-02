#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# RSS + Clash 栈：在本机拉取/构建栈镜像并打包为 tar，用于无法访问 Docker Hub 的服务器
# 依赖：Docker、Docker Compose V2（docker compose）、已配置 .env 与 CLASH_AIO_PATH
# 用法：在 rss 项目根目录执行 ./scripts/stack-images-pack.sh
# 输出：STACK_IMAGES_TAR 指定路径，未设置时默认为项目根目录/rss-stack-images.tar
# 可选：SKIP_BUILD=1 时仅打包已有镜像（不拉取、不构建），本地已运行过栈时使用
# ---------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RSS_ROOT"

# ---------- 检测 Docker Compose V2 ----------
COMPOSE_CMD="docker compose"
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  echo "错误：未检测到 Docker 或 Docker Compose V2（docker compose）。请安装 Docker 并启用 Compose 插件。"
  exit 1
fi

# ---------- 确保子项目已初始化 ----------
if [ -f .gitmodules ]; then
  git submodule update --init --recursive || true
fi

# ---------- 环境与 CLASH_AIO_PATH、RSSHUB_PATH ----------
"$SCRIPT_DIR/stack-pre-install.sh" || true
CLASH_AIO_PATH="${CLASH_AIO_PATH:-./clash-aio}"
RSSHUB_PATH="${RSSHUB_PATH:-./RSSHub}"
if [ -f .env ]; then
  set -a
  # shellcheck source=/dev/null
  source .env 2>/dev/null || true
  set +a
  [ -n "${CLASH_AIO_PATH}" ] || CLASH_AIO_PATH="./clash-aio"
  [ -n "${RSSHUB_PATH}" ] || RSSHUB_PATH="./RSSHub"
fi
export RSSHUB_PATH
if [ ! -d "$CLASH_AIO_PATH" ]; then
  CLASH_AIO_PATH="$RSS_ROOT/$CLASH_AIO_PATH"
fi
if [ ! -d "$CLASH_AIO_PATH" ] || [ ! -f "$CLASH_AIO_PATH/Dockerfile" ] || [ ! -f "$CLASH_AIO_PATH/preprocess.sh" ]; then
  echo "错误：CLASH_AIO_PATH 无效或缺少 Dockerfile/preprocess.sh，请配置 .env 或初始化 clash-aio submodule。"
  exit 1
fi
CLASH_AIO_PATH="$(cd "$CLASH_AIO_PATH" && pwd)"
export CLASH_AIO_PATH
[ ! -d "$RSSHUB_PATH" ] && RSSHUB_PATH="$RSS_ROOT/$RSSHUB_PATH"
export RSSHUB_PATH
[ -n "${BUILD_PROXY}" ] && export BUILD_PROXY

# ---------- 输出路径 ----------
OUTPUT_TAR="${STACK_IMAGES_TAR:-$RSS_ROOT/rss-stack-images.tar}"
OUTPUT_DIR="$(dirname "$OUTPUT_TAR")"
if [ ! -d "$OUTPUT_DIR" ]; then
  echo "错误：输出目录不存在: $OUTPUT_DIR"
  exit 1
fi

# ---------- 拉取/构建（SKIP_BUILD=1 时跳过，仅用本地已有镜像打包） ----------
if [ "${SKIP_BUILD}" != "1" ]; then
  echo "拉取 tindy2013/subconverter:latest、redis:alpine..."
  docker pull tindy2013/subconverter:latest
  docker pull redis:alpine
  echo "构建 clash-with-ui、rsshub 镜像..."
  $COMPOSE_CMD -f docker-compose.stack.yml build
else
  echo "SKIP_BUILD=1：跳过拉取与构建，使用本地已有镜像打包。"
fi

# ---------- 打包为单一 tar ----------
echo "打包四个镜像到 $OUTPUT_TAR ..."
docker save \
  tindy2013/subconverter:latest \
  redis:alpine \
  clash-with-ui:latest \
  rsshub:stack \
  -o "$OUTPUT_TAR"

echo "已生成: $OUTPUT_TAR（已加入 .gitignore）"
echo "本地已有镜像时下次可: SKIP_BUILD=1 ./scripts/stack-images-pack.sh"
echo "一键上传到服务器并 load: ./scripts/stack-upload-to-server.sh"
echo "或手动: scp 到服务器后，在 rss 根目录执行 ./scripts/stack-images-load.sh && ./scripts/stack-build-and-up.sh"
