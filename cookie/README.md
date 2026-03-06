# Cookie 目录

B 站、微博等站点的 Cookie 放在此目录，通过脚本合并到 `.env` 并重启 rsshub。

- **B 站**：`bilibili.txt` 或 `bilibili_cookies.py`，获取方式见 [docs/bilibili-cookie-docker.md](../docs/bilibili-cookie-docker.md)（无痕登录 bilibili.com → F12 → Application → Cookies 复制）。
- **微博**：`weibo.txt` 或 `weibo_cookies.py`，须使用 **m.weibo.cn** 的请求 Cookie，见 [docs/troubleshooting.md](../docs/troubleshooting.md) 第八节与 [docs/folo-add-feeds.md](../docs/folo-add-feeds.md)。

格式：单行 `name1=value1; name2=value2; ...` 或 Python 字典（`*_cookies.py`）。本目录 `*.txt`、`*_cookies.py` 等已 `.gitignore`，不会提交。

## 使用

在 rss 项目根目录执行：

- **远程（推荐）**：`./scripts/upload-cookie-and-apply-remote.sh` — 将本目录全部 Cookie 上传到服务器、合并 .env、重启 rsshub（并清理微博 Redis 缓存）。
- **B 站本地**：`./scripts/apply-bilibili-cookie.sh --uid <uid>`；仅合并不重启加 `--no-restart`；远程加 `--remote`。
- **微博本地**：`./scripts/apply-weibo-cookie.sh`；远程加 `--remote`。
