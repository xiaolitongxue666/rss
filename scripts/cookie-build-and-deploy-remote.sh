#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 一键：本地从 cookie/ 构建 BILIBILI_COOKIE_<uid> 配置，scp 上传到 moicen 并重启 rsshub。
# 等价于：./scripts/apply-bilibili-cookie.sh [--uid <uid>] [--source py|txt] --remote
# 用法（在 rss 项目根目录执行）：
#   ./scripts/cookie-build-and-deploy-remote.sh
#   ./scripts/cookie-build-and-deploy-remote.sh --uid 1282360
#   ./scripts/cookie-build-and-deploy-remote.sh --uid 1282360 --source txt
# 环境变量：REMOTE_USER、REMOTE_HOST、REMOTE_ALCHEMY_DIR（同 stack-upload-to-server.sh）
# ---------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RSS_ROOT"

if [ ! -f "cookie/bilibili_cookies.py" ] && [ ! -f "cookie/bilibili.txt" ]; then
  echo "错误：未找到 cookie/bilibili_cookies.py 或 cookie/bilibili.txt，请先按 docs/bilibili-cookie-docker.md 准备 Cookie 文件。" >&2
  exit 1
fi

echo "=== 本地构建 Cookie 配置并部署到远程（scp + 合并 .env + 重启 rsshub）==="
exec "$SCRIPT_DIR/apply-bilibili-cookie.sh" "$@" --remote
