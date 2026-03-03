# Cookie 目录

从浏览器导出的 B 站 Cookie 可放在此目录，再通过 `./scripts/apply-bilibili-cookie.sh --uid <uid>` 合并到 `.env` 并重启 rsshub。

**获取方式**：无痕模式登录 bilibili.com → F12 → **Application（应用）** → Storage → Cookies → 选中 `https://www.bilibili.com` → 右侧表格 **Ctrl+A / Ctrl+C** 全选复制；将表格文本转化为 `name=value; name=value; ...` 或 Python 字典后保存为本目录下的 `bilibili.txt` 或 `bilibili_cookies.py`。完整步骤（含为何用 Application 而非 document.cookie、安全注意）见 [docs/bilibili-cookie-docker.md](../docs/bilibili-cookie-docker.md)。

## 格式说明

- **bilibili.txt**：单行 Cookie 字符串（`name1=value1; name2=value2; ...`），与请求头 `Cookie` 一致，可直接用于项目 `.env` 中的 `BILIBILI_COOKIE`。
- **bilibili_cookies.py**：Python 字典格式，便于在脚本中使用，例如：`requests.get(url, cookies=cookies)` 或 `httpx.get(url, cookies=cookies)`。
- 本目录下 `*.txt`、`*.cookies`、`*.json`、`*_cookies.py` 已加入 `.gitignore`，不会提交到仓库。

## 使用

在 rss 项目根目录执行（会合并到 `.env` 并重启 rsshub）：

```bash
./scripts/apply-bilibili-cookie.sh --uid <你的B站uid>
```

或仅合并不重启：`./scripts/apply-bilibili-cookie.sh --uid <uid> --no-restart`。远程服务器：`./scripts/apply-bilibili-cookie.sh --uid <uid> --remote`。变量名为 `BILIBILI_COOKIE_<uid>`，见 [docs/bilibili-cookie-docker.md](../docs/bilibili-cookie-docker.md)。
