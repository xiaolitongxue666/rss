# Docker 环境下设置 B 站 Cookie（完整流程）

**说明**：当前 RSSHub 仅支持**环境变量**配置，本栈使用项目根目录的 `.env`，与官方一致。请勿采用「挂载 config.js」等旧教程做法。

---

## 一、前置说明（核心概念）

- **配置方式**：RSSHub 通过**环境变量**读取 Cookie（无 config.js 或挂载配置文件）；本栈通过 `env_file: - .env` 传入，在项目根目录的 `.env` 中配置即可。
- **变量格式**：`BILIBILI_COOKIE_<uid>=<Cookie 字符串>`，`<uid>` 为 B 站用户 uid（与订阅路由中的 uid 一致）；多账号可配置多行，如 `BILIBILI_COOKIE_2267573`、`BILIBILI_COOKIE_123456`。不能使用单一键 `BILIBILI_COOKIE`。
- **作用**：仅用于需要登录态的路由（如 UP 主动态、关注动态、粉丝、收藏夹、稍后再看等）；纯投稿、热搜等路由无需 Cookie。
- **安全**：`.env` 已加入 .gitignore，切勿提交或在不安全渠道粘贴 Cookie；脚本与文档不输出、不记录 Cookie 内容。

---

## 二、获取 B 站 Cookie（无痕、一次成功）

### 2.1 打开无痕模式

- Chrome / Edge：`Ctrl+Shift+N`
- Firefox：`Ctrl+Shift+P`

### 2.2 在无痕窗口内

1. 打开 B 站首页 https://www.bilibili.com ，登录你的账号。
2. 按 **F12** 打开开发者工具，切换到 **Network（网络）** 标签。

### 2.3 触发请求

- 按 **F5** 刷新页面；或  
- 在地址栏打开 `https://api.vc.bilibili.com/dynamic_svr/v1/dynamic_svr/dynamic_new?uid=0&type=8` 后刷新。

只要页面会向 **api.bilibili.com** 发请求即可，请求路径可以是任意接口（例如 `dynamic_svr`、`x/kv-frontend/namespace/data` 等）。

### 2.4 复制 Cookie：Application 面板全选复制（含 HttpOnly）

1. 在开发者工具中切换到 **Application（应用）** 面板（Chrome/Edge；Firefox 为 **存储**）。
2. 左侧 **Storage → Cookies** 下点击 **https://www.bilibili.com**（或 **.bilibili.com**），右侧会显示该域名下所有 Cookie 的表格（含 Name、Value、Domain、Path、Expires 等列）。
3. 在右侧表格区域点击一下，按 **Ctrl+A**（Mac：Cmd+A）全选，再按 **Ctrl+C**（Cmd+C）复制，得到的是 Tab 分隔的多列文本。
4. **转化为可用格式**：
   - 将复制出的表格文本交给 AI/脚本识别 Tab 分隔、剔除 Expires 等列，只保留 Name 与 Value，输出为 **Cookie 字符串**或 **Python 字典**，保存为 `cookie/bilibili.txt` 或 `cookie/bilibili_cookies.py`。
   - 之后在 rss 根目录执行 `./scripts/apply-bilibili-cookie.sh --uid <uid>` 即可合并到 .env 并重启 rsshub。

Application 面板拿到的是该域名下**当前存储的最完整状态**，包含带 **HttpOnly** 的字段（如 `SESSDATA`）；`document.cookie` 无法读取 HttpOnly，故必须用 Application（或 Network 请求头）获取完整登录态。

示例形式（仅格式参考，勿用示例值）：

```
SESSDATA=abc123xxx; bili_jct=456defxxx; DedeUserID=789ghi...
```

### 2.5 说明与安全

- 动态类路由建议整段复制；仅用投稿/专栏/粉丝等路由时，部分场景仅 `SESSDATA` 也可（以实测为准）。
- Cookie 有效期有限，过期后需重新获取。
- **安全**：`SESSDATA` 等相当于临时账号凭证，请勿提交到版本库或在不安全渠道粘贴；本栈 `.env` 与 `cookie/` 下敏感文件已加入 .gitignore。

---

## 三、在 Docker 环境下配置（.env）

### 3.1 准备 .env

在**运行 Docker 的机器**上，进入 rss 项目根目录。若没有 `.env`，执行：

```bash
cp .env.stack.example .env
```

### 3.2 写入变量

在 `.env` 中新增（或修改）一行，例如：

```
BILIBILI_COOKIE_2267573="SESSDATA=xxx; bili_jct=xxx; DedeUserID=xxx; ..."
```

- 整段 Cookie 建议用**双引号**包裹，避免 `=`、`;` 被解析错误。
- 若值内包含双引号，需转义或改用单引号。

### 3.3 多账号

多行配置不同 uid 即可，例如：

```
BILIBILI_COOKIE_123456="..."
BILIBILI_COOKIE_789012="..."
```

### 3.4 生效

保存后执行：

```bash
docker compose -f docker-compose.stack.yml up -d rsshub
```

或使用本栈的 `./scripts/stack-build-and-up.sh` 等，使容器重新加载环境变量。

### 3.5 从 cookie 目录生成并应用到 .env（推荐）

若已将 Cookie 保存在项目 `cookie/` 目录（如 [cookie/README.md](../cookie/README.md) 中的 `bilibili.txt` 或 `bilibili_cookies.py`），可用脚本自动生成 `BILIBILI_COOKIE_<uid>` 并合并到 `.env`，无需手动粘贴。

- **脚本**：[scripts/apply-bilibili-cookie.sh](../scripts/apply-bilibili-cookie.sh)（内部调用 [scripts/cookie-to-env.py](../scripts/cookie-to-env.py) 从 cookie 目录读取并生成 .env 行）
- **用法**（均在 rss 项目根目录执行）：
  - 本地：`./scripts/apply-bilibili-cookie.sh`（按提示输入 uid）或 `./scripts/apply-bilibili-cookie.sh --uid 2267573`；会将 Cookie 合并到本地 `.env` 并重启 rsshub。
  - 仅合并不重启：`./scripts/apply-bilibili-cookie.sh --uid 2267573 --no-restart`
  - 远程服务器：`./scripts/apply-bilibili-cookie.sh --uid 2267573 --remote`；会通过 scp 上传 Cookie 片段到服务器、在服务器上合并到 `.env` 并重启 rsshub。环境变量 `REMOTE_USER`、`REMOTE_HOST`、`REMOTE_ALCHEMY_DIR` 与 [scripts/stack-upload-to-server.sh](../scripts/stack-upload-to-server.sh) 一致（默认 `REMOTE_ALCHEMY_DIR=/home/alchemy/RSS`）。
- **多账号**：对每个 uid 执行一次（带不同 `--uid`），脚本会保留已有 `BILIBILI_COOKIE_<其他 uid>` 行，仅更新或追加当前 uid。
- **一键启动**：`./scripts/stack-from-zero.sh` 与 `./scripts/stack-build-and-up.sh` 在检测到 `cookie/bilibili_cookies.py` 或 `cookie/bilibili.txt` 且 `.env` 中尚无 `BILIBILI_COOKIE_*` 时，会提示执行 `./scripts/apply-bilibili-cookie.sh` 配置 Cookie。

### 3.6 一键：本地构建 Cookie + 上传 moicen + 重启

若希望一条命令完成「从 `cookie/` 构建配置 → scp 上传到 moicen 服务器 → 合并到服务器 `.env` → 重启 rsshub」，可使用：

- **脚本**：[scripts/cookie-build-and-deploy-remote.sh](../scripts/cookie-build-and-deploy-remote.sh)
- **用法**（在 rss 项目根目录执行）：
  - `./scripts/cookie-build-and-deploy-remote.sh` — 按提示输入 B 站 uid；
  - `./scripts/cookie-build-and-deploy-remote.sh --uid 2267573` — 指定 uid；
  - `./scripts/cookie-build-and-deploy-remote.sh --uid 2267573 --source txt` — 从 `cookie/bilibili.txt` 读取（默认从 `cookie/bilibili_cookies.py`）。
- **前提**：本机已存在 `cookie/bilibili_cookies.py` 或 `cookie/bilibili.txt`；本机可免密 `ssh`/`scp` 到 `REMOTE_USER@REMOTE_HOST`（建议配置 SSH 公钥）。
- **环境变量**：与 [stack-upload-to-server.sh](../scripts/stack-upload-to-server.sh) 一致：`REMOTE_USER`（默认 leonli）、`REMOTE_HOST`（默认 moicen.com）、`REMOTE_ALCHEMY_DIR`（默认 /home/alchemy/RSS）。成功后在服务器上 rsshub 已重启，Cookie 即生效。

---

## 四、降低被限流/封号风险（爬取间隔与缓存）

- **缓存**：本栈已配置 Redis，同一路由在缓存有效期内不会重复请求 B 站。可在 `.env` 中增加以下变量，拉长缓存时间、降低请求频率：
  - `CACHE_EXPIRE`：路由缓存时间（秒），RSSHub 默认 300；可设为 `600` 或 `900`，使同一订阅源至少间隔 10～15 分钟再请求。
  - `CACHE_CONTENT_EXPIRE`：内容缓存（秒），默认 3600；可适当增大（如 `7200`）。
- **阅读器**：避免对同一 B 站路由设置过短的刷新间隔；建议阅读器刷新间隔 ≥ 15～30 分钟。

---

## 五、验证生效

在浏览器中访问需 Cookie 的路由，例如：

```
https://你的RSSHub地址/bilibili/user/dynamic/<uid>
```

- 返回正常 RSS/XML → 配置生效。
- 若 403、412 或提示未登录 → Cookie 过期或无效，需重新获取；若频繁出现，可适当增大 `CACHE_EXPIRE` 并拉长阅读器刷新间隔。

---

## 六、412/503 风控与推荐用法

B 站路由可能返回 **412 Precondition Failed** 或 **503**，多为风控或 Cookie/uid 不匹配。**完整问题与解决梳理**见 [docs/troubleshooting.md](troubleshooting.md)。

- **Cookie 与 uid**：`BILIBILI_COOKIE_<uid>` 的 uid 为**你本人** B 站账号 UID；`/followings/video/:uid` 的 uid 必须与某条已配置的 Cookie 的 uid 一致。配置后执行 `./scripts/cookie-build-and-deploy-remote.sh --uid <你的uid>` 推送到服务器。
- **优先用「用户关注视频动态」**：订阅一条 `/bilibili/followings/video/<你的uid>` 可减少风控（参见 [RSSHub #20406](https://github.com/DIYgod/RSSHub/issues/20406)）。
- **仍 412 时**：设置 `PROXY_URL_REGEX` 使 B 站直连、增大 `CACHE_EXPIRE`、`RSSHUB_PLUGIN_FILTER=true` 与 `?filterout=author`。详见 [troubleshooting.md](troubleshooting.md)。

---

## 七、常见问题

- **配置后仍报错**：检查 Cookie 是否完整、是否过期；变量名是否为 `BILIBILI_COOKIE_<uid>` 且 uid 为数字。
- **容器重启后未生效**：确认修改的是运行 compose 的目录下的 `.env`，且执行了 `up -d rsshub`。
- **安全**：勿提交 `.env`，勿在不安全渠道粘贴 Cookie。

---

## 八、可选：使用脚本安全写入

- **从剪贴板/手动输入**：[scripts/add-bilibili-cookie.sh](../scripts/add-bilibili-cookie.sh) — 在 rss 项目根目录执行 `./scripts/add-bilibili-cookie.sh`，按提示输入 uid 与 Cookie（粘贴时不回显）；脚本不会 echo 或记录 Cookie。
- **从 cookie 目录自动合并**：见上文 [3.5 从 cookie 目录生成并应用到 .env](#35-从-cookie-目录生成并应用到-env推荐)；支持本地与远程（`--remote`），详见 [apply-bilibili-cookie.sh](../scripts/apply-bilibili-cookie.sh) 内注释。
- **一键部署到远程**：[scripts/cookie-build-and-deploy-remote.sh](../scripts/cookie-build-and-deploy-remote.sh) — 本地构建 Cookie 配置后 scp 上传到 moicen、合并 .env 并重启 rsshub，见 [3.6 一键：本地构建 Cookie + 上传 moicen + 重启](#36-一键本地构建-cookie--上传-moicen--重启)。
