#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# RSS + Clash 栈：构建前环境检查与 .env 准备
# 可选：设置 SKIP_PRE_INSTALL=1 跳过本脚本
# 用法：在 rss 项目根目录执行 ./scripts/stack-pre-install.sh，或由 stack-build-and-up.sh 自动调用
# ---------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$RSS_ROOT"

[ -n "${SKIP_PRE_INSTALL}" ] && [ "${SKIP_PRE_INSTALL}" != "0" ] && exit 0

# ---------- 若无 .env 则从模板复制 ----------
if [ ! -f .env ]; then
  if [ -f .env.stack.example ]; then
    cp .env.stack.example .env
    echo "已从 .env.stack.example 创建 .env，请编辑 .env 填写 RAW_SUB_URL（必填）及可选 CLASH_AIO_PATH、Cookie。"
  else
    echo "错误：缺少 .env.stack.example，无法创建 .env"
    exit 1
  fi
fi

# ---------- 检测 CLASH_AIO_PATH：若未配置或指向不存在路径，尝试常见位置 ----------
# 常见位置：submodule ./clash-aio、同级 ../clash-aio、../../Proxy/clash-aio
CLASH_AIO_PATH=""
if [ -f .env ]; then
  CLASH_AIO_PATH=$(grep -E '^CLASH_AIO_PATH=' .env 2>/dev/null | cut -d= -f2- | sed 's/^[" ]*//;s/[" ]*$//' || true)
fi

is_valid_clash_dir() {
  [ -d "$1" ] && [ -f "$1/Dockerfile" ] && [ -f "$1/preprocess.sh" ]
}

if [ -n "$CLASH_AIO_PATH" ]; then
  # 相对路径先相对 rss 根目录解析
  if [ ! -d "$CLASH_AIO_PATH" ]; then
    CLASH_AIO_PATH="$RSS_ROOT/$CLASH_AIO_PATH"
  fi
fi

if ! is_valid_clash_dir "$CLASH_AIO_PATH"; then
  for candidate in "$RSS_ROOT/clash-aio" "$RSS_ROOT/../clash-aio" "$RSS_ROOT/../../Proxy/clash-aio"; do
    if is_valid_clash_dir "$candidate"; then
      # 写入或更新 .env 中的 CLASH_AIO_PATH（相对 rss 根的相对路径）
      rel_path="${candidate#$RSS_ROOT/}"
      [ "$rel_path" = "$candidate" ] && rel_path="./clash-aio"
      if [ "$candidate" = "$RSS_ROOT/clash-aio" ]; then
        rel_path="./clash-aio"
      elif [ "$candidate" = "$RSS_ROOT/../clash-aio" ]; then
        rel_path="../clash-aio"
      elif [ "$candidate" = "$RSS_ROOT/../../Proxy/clash-aio" ]; then
        rel_path="../../Proxy/clash-aio"
      else
        rel_path="$candidate"
      fi
      if grep -q '^CLASH_AIO_PATH=' .env 2>/dev/null; then
        (grep -v '^CLASH_AIO_PATH=' .env 2>/dev/null; echo "CLASH_AIO_PATH=$rel_path") > .env.tmp && mv .env.tmp .env
      else
        echo "CLASH_AIO_PATH=$rel_path" >> .env
      fi
      echo "已检测到 clash-aio 并写入 .env: CLASH_AIO_PATH=$rel_path"
      break
    fi
  done
fi

# ---------- 若仍无有效 clash-aio，检查是否为未初始化的 submodule ----------
if ! is_valid_clash_dir "$RSS_ROOT/clash-aio"; then
  if [ -f .gitmodules ] && grep -q 'clash-aio' .gitmodules 2>/dev/null; then
    echo "提示：clash-aio 为 git submodule，请先执行: git submodule update --init --recursive"
    exit 1
  fi
fi

# ---------- 检查 RSSHub 子项目（默认 ./RSSHub） ----------
RSSHUB_PATH="${RSSHUB_PATH:-./RSSHub}"
if [ -f .env ]; then
  env_rsshub=$(grep -E '^RSSHUB_PATH=' .env 2>/dev/null | cut -d= -f2- | sed 's/^[" ]*//;s/[" ]*$//' || true)
  [ -n "$env_rsshub" ] && RSSHUB_PATH="$env_rsshub"
fi
if [ ! -d "$RSSHUB_PATH" ]; then
  [ -d "$RSS_ROOT/$RSSHUB_PATH" ] && RSSHUB_PATH="$RSS_ROOT/$RSSHUB_PATH"
fi
if [ ! -d "$RSSHUB_PATH" ] || [ ! -f "$RSSHUB_PATH/Dockerfile" ]; then
  if [ -f .gitmodules ] && grep -q 'RSSHub' .gitmodules 2>/dev/null; then
    echo "错误：RSSHub 子项目未初始化或缺少 Dockerfile，请先执行: git submodule update --init --recursive"
    exit 1
  else
    echo "错误：RSSHUB_PATH 指向的目录不存在或缺少 Dockerfile: $RSSHUB_PATH"
    exit 1
  fi
fi

# ---------- 再次校验：若 .env 中有 CLASH_AIO_PATH，检查指向是否有效 ----------
if [ -f .env ]; then
  set -a
  # shellcheck source=/dev/null
  source .env 2>/dev/null || true
  set +a
  CHECK_PATH="${CLASH_AIO_PATH:-}"
  [ -n "$CHECK_PATH" ] && [ ! -d "$CHECK_PATH" ] && CHECK_PATH="$RSS_ROOT/$CHECK_PATH"
  if [ -n "$CHECK_PATH" ] && ! is_valid_clash_dir "$CHECK_PATH"; then
    echo "错误：.env 中 CLASH_AIO_PATH 指向的目录不存在或缺少 Dockerfile/preprocess.sh"
    echo "请将 clash-aio 放在 rss 下的 ./clash-aio（submodule）或任意路径，并在 .env 中设置 CLASH_AIO_PATH=该路径"
    exit 1
  fi
fi

# ---------- 可选：提示 RAW_SUB_URL 未填 ----------
if [ -f .env ] && ! grep -q '^RAW_SUB_URL=.\+' .env 2>/dev/null; then
  echo "提示：.env 中 RAW_SUB_URL 尚未填写，后续 stack-build-and-up.sh 会提示是否继续。"
fi

echo "pre-install 检查完成。"
