#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# RSS + Clash 栈：整体验证（系统性测试通过标准）
# 检查 RSSHub 1200、Subconverter 25501，可选 Clash 容器健康
# 用法：在 rss 项目根目录执行 ./scripts/stack-verify.sh
# 退出码：0 表示通过（RSSHub + Subconverter 均正常），非 0 表示未通过
# ---------------------------------------------------------------------------

set -e

FAILED=0

# ---------- RSSHub ----------
if curl -sf -o /dev/null "http://127.0.0.1:1200/" 2>/dev/null; then
  echo "通过: RSSHub http://127.0.0.1:1200/"
else
  echo "失败: RSSHub 1200 未响应"
  FAILED=1
fi

# ---------- Subconverter（接受任意 HTTP 响应，因根路径可能非 2xx） ----------
if curl -s -o /dev/null --connect-timeout 2 --max-time 5 "http://127.0.0.1:25501/" 2>/dev/null; then
  echo "通过: Subconverter http://127.0.0.1:25501/"
else
  echo "失败: Subconverter 25501 未响应"
  FAILED=1
fi

# ---------- Clash 容器（可选，仅告警） ----------
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'rss-stack-clash-with-ui'; then
  if docker exec rss-stack-clash-with-ui wget -q -O /dev/null "http://127.0.0.1:7890" 2>/dev/null || \
     docker exec rss-stack-clash-with-ui curl -sf -o /dev/null "http://127.0.0.1:7890" 2>/dev/null; then
    echo "通过: Clash 容器内 7890 可达"
  else
    echo "告警: Clash 容器在运行但 7890 未响应（不视为测试失败）"
  fi
elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q 'rss-stack-clash-with-ui'; then
  echo "告警: rss-stack-clash-with-ui 存在但未运行（不视为测试失败）"
else
  echo "告警: 未发现 rss-stack-clash-with-ui 容器（不视为测试失败）"
fi

if [ "$FAILED" -eq 0 ]; then
  echo "整体验证通过。"
  exit 0
else
  echo "整体验证未通过。"
  exit 1
fi
