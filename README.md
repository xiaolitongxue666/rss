# rss

主题项目：统一编排、构建与部署 **RSSHub** 与 **Clash（clash-aio）**，实现一键更新、构建、部署。

- **RSSHub**：以 git submodule 形式引入（默认 `./RSSHub`），从 [官方仓库](https://github.com/DIYgod/RSSHub) fork 更新，本仓库不修改其核心代码。
- **clash-aio**：以 git submodule 形式引入（默认 `./clash-aio`），作为整栈外网代理。

## 快速开始

1. 克隆并初始化子项目：`git clone --recurse-submodules <rss-repo-url>`，或克隆后执行 `git submodule update --init --recursive`。
2. 复制 `.env.stack.example` 为 `.env`，填写 **RAW_SUB_URL**（必填）；可选 Cookie 可存于 `cookie/` 目录后执行 `./scripts/apply-bilibili-cookie.sh --uid <uid>`，见 [docs/bilibili-cookie-docker.md](docs/bilibili-cookie-docker.md)。
3. 在项目根目录执行：`./scripts/stack-build-and-up.sh`。

**环境要求**：Docker 与 Docker Compose V2（`docker compose`）。

## 文档

- **部署与使用**：[DEPLOYMENT-STACK.md](DEPLOYMENT-STACK.md) — 构建、启动、环境变量、离线/备选构建流程。
- **部署计划（操作顺序）**：[docs/deployment-plan.md](docs/deployment-plan.md) — 本地与远程部署步骤、Cookie 配置时机。
- **B 站 Cookie 配置**：[docs/bilibili-cookie-docker.md](docs/bilibili-cookie-docker.md) — 获取 Cookie、`cookie/` 目录与 `apply-bilibili-cookie.sh`（本地/远程）。
- **故障排查（B 站/微博等）**：[docs/troubleshooting.md](docs/troubleshooting.md) — B 站 412/503、微博 /weibo/friends、PROXY_URL_REGEX、Cookie 获取。
- **在 FOLO（或其它 RSS 阅读器）中添加订阅源**：[docs/folo-add-feeds.md](docs/folo-add-feeds.md)。
- **RSSHub 路由与参数**：[docs.rsshub.app](https://docs.rsshub.app/guide/)。

## 栈脚本（均在 rss 根目录执行）

| 脚本 | 说明 |
|------|------|
| `stack-pre-install.sh` | 前置检查与 .env、子项目路径 |
| `stack-build-and-up.sh` | 一键构建并启动（日常使用） |
| `stack-from-zero.sh` | 从零构建 + 分步启动 + 验证 |
| `stack-down.sh` / `stack-stop-all.sh` | 停止栈或所有相关容器 |
| `stack-verify.sh` | 验证 1200 / 25501 / Clash |
| `stack-images-pack.sh` | 本机构建并打包镜像 tar（输出到项目内 `rss-stack-images.tar`，已 .gitignore） |
| `stack-upload-to-server.sh` | 本机打包并上传 tar 到服务器、在服务器上 load（可配置 REMOTE_*） |
| `stack-images-load.sh` | 服务器从 tar 加载镜像 |
| `stack-server-update-and-start.sh` | 服务器更新后一键：检查权限 → 加载镜像 → 停旧容器 → 启动 |
| `upload-cookie-and-apply-remote.sh` | 将 `cookie/`（B 站+微博）上传到服务器、合并 .env、重启 rsshub（推荐远程更新 Cookie） |
| `apply-bilibili-cookie.sh` | 从 `cookie/` 生成 BILIBILI_COOKIE_<uid> 并合并到 .env（`--local` / `--remote`） |
| `apply-weibo-cookie.sh` | 从 `cookie/` 生成 WEIBO_COOKIES 并合并到 .env（`--local` / `--remote`） |

## 更新子项目

- 更新 RSSHub：`git submodule update --remote RSSHub`，或在 `RSSHub` 目录内 `git pull upstream master` 后回到 rss 提交新 submodule commit。
- 更新 clash-aio：`git submodule update --remote clash-aio`。

## License

见 [LICENSE](LICENSE)。
