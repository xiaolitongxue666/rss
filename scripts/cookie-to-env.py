#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# 从 cookie/bilibili_cookies.py 或 cookie/bilibili.txt 生成 Cookie 字符串或 .env 行
# 用法（在 rss 项目根目录执行）：
#   python3 scripts/cookie-to-env.py                    # 输出单行 cookie 字符串
#   python3 scripts/cookie-to-env.py --uid 2267573       # 输出 BILIBILI_COOKIE_2267573="..."
#   python3 scripts/cookie-to-env.py --source txt       # 从 cookie/bilibili.txt 读取
# ---------------------------------------------------------------------------

import argparse
import ast
import os
import sys


def _script_dir():
    return os.path.dirname(os.path.abspath(__file__))


def _rss_root():
    return os.path.dirname(_script_dir())


def cookie_string_from_py(cookie_py_path: str) -> str:
    """从 cookie/bilibili_cookies.py 解析 cookies 字典，返回 name=value; ... 字符串。"""
    with open(cookie_py_path, "r", encoding="utf-8") as f:
        tree = ast.parse(f.read())
    cookies = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign):
            for t in node.targets:
                if isinstance(t, ast.Name) and t.id == "cookies" and isinstance(node.value, ast.Dict):
                    for k, v in zip(node.value.keys, node.value.values):
                        try:
                            key = ast.literal_eval(k)
                            val = ast.literal_eval(v)
                            if isinstance(key, str) and isinstance(val, str):
                                cookies[key] = val
                        except (ValueError, TypeError):
                            continue
                    break
    if not cookies:
        raise ValueError(f"未在 {cookie_py_path} 中解析到 cookies 字典")
    return "; ".join(f"{k}={v}" for k, v in cookies.items())


def cookie_string_from_txt(txt_path: str) -> str:
    """从 cookie/bilibili.txt 读取单行 cookie 字符串（去除首尾空白与换行）。"""
    with open(txt_path, "r", encoding="utf-8") as f:
        line = f.read().strip().replace("\n", " ")
    if not line:
        raise ValueError(f"{txt_path} 为空")
    return line


def main():
    parser = argparse.ArgumentParser(description="从 cookie 目录生成 .env 用 Cookie 字符串或 BILIBILI_COOKIE_<uid> 行")
    parser.add_argument("--uid", type=str, default="", help="B 站用户 uid，指定时输出 BILIBILI_COOKIE_<uid>=... 行")
    parser.add_argument("--source", choices=("py", "txt"), default="py", help="来源：py=cookie/bilibili_cookies.py，txt=cookie/bilibili.txt")
    args = parser.parse_args()

    root = _rss_root()
    os.chdir(root)

    if args.source == "py":
        path = os.path.join(root, "cookie", "bilibili_cookies.py")
        if not os.path.isfile(path):
            print(f"错误：不存在 {path}", file=sys.stderr)
            sys.exit(1)
        cookie_str = cookie_string_from_py(path)
    else:
        path = os.path.join(root, "cookie", "bilibili.txt")
        if not os.path.isfile(path):
            print(f"错误：不存在 {path}", file=sys.stderr)
            sys.exit(1)
        cookie_str = cookie_string_from_txt(path)

    if args.uid:
        # 输出 .env 行，双引号内若有 " 需转义
        escaped = cookie_str.replace("\\", "\\\\").replace('"', '\\"')
        print(f'BILIBILI_COOKIE_{args.uid}="{escaped}"')
    else:
        print(cookie_str)


if __name__ == "__main__":
    main()
