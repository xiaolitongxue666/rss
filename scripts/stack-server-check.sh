#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# RSS + Clash 栈：在服务器本机做端口与出网检查（便于 SSH 登录后自检）
# 检查：本机 1200/25501、Clash 容器内 7890、本机直连 ipinfo 是否为中国
# 用法：在 rss 项目根目录执行 ./scripts/stack-server-check.sh
# ---------------------------------------------------------------------------

set -e

echo "========== 本机端口 =========="
if curl -sf -o /dev/null --connect-timeout 5 "http://127.0.0.1:1200/" 2>/dev/null; then
  echo "通过: RSSHub http://127.0.0.1:1200/"
else
  echo "失败: 本机 1200 未响应"
fi
if curl -s -o /dev/null --connect-timeout 3 --max-time 5 "http://127.0.0.1:25501/" 2>/dev/null; then
  echo "通过: Subconverter http://127.0.0.1:25501/"
else
  echo "失败: 本机 25501 未响应"
fi

echo ""
echo "========== Clash 代理（容器内 7890）=========="
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'rss-stack-clash-with-ui'; then
  if docker exec rss-stack-clash-with-ui wget -q -O /dev/null "http://127.0.0.1:7890" 2>/dev/null; then
    echo "通过: Clash 容器内 7890 可达"
  else
    echo "告警: Clash 容器在运行但 7890 未响应"
  fi
else
  echo "告警: rss-stack-clash-with-ui 未运行"
fi

echo ""
echo "========== 本机直连出网（ipinfo.io）=========="
IPINFO=""
IPINFO="$(curl -s --connect-timeout 10 https://ipinfo.io/json 2>/dev/null)" || true
if [ -n "$IPINFO" ]; then
  echo "$IPINFO"
  if echo "$IPINFO" | grep -q '"country": "CN"'; then
    echo "结论: 本机直连为中国大陆 (CN)"
  else
    echo "结论: 本机直连非中国大陆"
  fi
else
  echo "失败: 无法访问 ipinfo.io"
fi

echo ""
echo "========== 容器状态 =========="
docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null | grep -E 'rss-stack|NAMES' || true
