#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# RSS + Clash 栈：一键退出服务并停止相关容器
# 内部调用 stack-stop-all.sh（停止 stack、默认 compose、独立 clash-aio compose）
# 用法：在 rss 项目根目录执行 ./scripts/stack-down.sh
# ---------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RSS_ROOT"

"$SCRIPT_DIR/stack-stop-all.sh"
echo "已退出服务，相关容器已停止。"
