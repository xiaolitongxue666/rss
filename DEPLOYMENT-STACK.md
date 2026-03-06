# RSS + Clash 栈部署说明

本仓库为**主题项目**，负责 RSSHub + Clash + Redis + Subconverter 的统一编排与构建。RSSHub 与 clash-aio 以 **git submodule** 形式引入，核心代码不在此仓库修改；RSSHub 通过内网使用 Clash 代理访问外网，国内源直连；Cookie 等通过环境变量配置。

**操作顺序清单**：本地与远程部署步骤、Cookie 配置时机见 [docs/deployment-plan.md](docs/deployment-plan.md)。

### 快速开始

1. 克隆并初始化子项目：`git clone --recurse-submodules <rss-repo-url>`，或克隆后执行 `git submodule update --init --recursive`（会初始化 RSSHub 与 clash-aio）。
2. 复制 `.env.stack.example` 为 `.env`，填写 **RAW_SUB_URL**（必填）及可选 RSSHUB_PATH、CLASH_AIO_PATH、Cookie。
3. 在 rss 项目根目录执行：`./scripts/stack-build-and-up.sh`。

**环境要求**：本栈脚本仅支持 **Docker Compose V2**（`docker compose` 插件），不支持已废弃的独立命令 `docker-compose`。请安装 Docker 并启用 Compose 插件。

### 栈脚本索引（均在 rss 根目录执行）

| 脚本 | 说明 |
|------|------|
| `stack-pre-install.sh` | 前置检查与 .env 准备（可由其他脚本自动调用） |
| `stack-build-and-up.sh` | 一键构建并启动（日常使用） |
| `stack-from-zero.sh` | 从零构建 + 分步启动 + 验证（系统性测试） |
| `stack-down.sh` | 一键退出服务并停止相关容器 |
| `stack-stop-all.sh` | 停止所有相关容器 |
| `stack-verify.sh` | 仅验证 1200 / 25501 / 可选 Clash |
| `stack-images-pack.sh` | 本机拉取/构建栈镜像并打包为 tar（输出到项目内 `rss-stack-images.tar`，已 .gitignore）；本地已有镜像时可用 `SKIP_BUILD=1` 仅打包不构建 |
| `stack-upload-to-server.sh` | 本机打包并上传 tar 到服务器、在服务器上 docker load（可设 REMOTE_USER/REMOTE_HOST/REMOTE_ALCHEMY_DIR；SKIP_PACK=1 仅上传已有 tar） |
| `stack-images-load.sh` | 服务器从 tar 加载镜像（用于离线部署） |
| `stack-server-update-and-start.sh` | 服务器端更新后一键流程：检查 Docker 权限 → 加载镜像 tar（若存在）→ 停止旧容器 → 启动栈 |
| `stack-server-check.sh` | 服务器本机检查 1200/25501、Clash 7890、本机出网 ipinfo |
| `apply-bilibili-cookie.sh` | 从 `cookie/` 目录生成 `BILIBILI_COOKIE_<uid>` 并合并到 .env；支持 `--local`（默认）/`--remote`、`--no-restart`；详见 [docs/bilibili-cookie-docker.md](docs/bilibili-cookie-docker.md) |
| `apply-weibo-cookie.sh` | 从 `cookie/` 目录生成 `WEIBO_COOKIES` 并合并到 .env；支持 `--local`（默认）/`--remote`、`--no-restart` |
| `cookie-to-env.py` | 被 apply-bilibili-cookie.sh / apply-weibo-cookie.sh 调用，从 cookie/ 生成 .env 行（`--site bilibili|weibo`）；亦可单独执行输出 Cookie 字符串 |

**服务器更新后**：拉代码后可直接执行 `./scripts/stack-server-update-and-start.sh`（内含：Docker 权限检查 → 加载镜像 → 停止旧容器 → 启动）；或按顺序执行：加载镜像 → `stack-down.sh` → `stack-build-and-up.sh`。**Cookie**：若需 B 站等登录态路由，在本机执行 `./scripts/apply-bilibili-cookie.sh --uid <uid> --remote` 将 Cookie 合并到服务器 .env 并重启 rsshub；微博执行 `./scripts/apply-weibo-cookie.sh --remote`。或登录服务器后按 [docs/bilibili-cookie-docker.md](docs/bilibili-cookie-docker.md) 手动配置。

---

## 零、服务器端前置（Docker 权限）

在服务器上运行栈脚本的用户（如 `alchemy`）需能访问 Docker 守护进程，否则会报错：`permission denied while trying to connect to the Docker daemon socket`。

**一次性配置**（用具备 sudo 的账号执行）：

```bash
sudo usermod -aG docker alchemy
```

**生效方式**（二选一）：

- **推荐**：该用户完全退出登录后重新登录（再次 `sudo su - alchemy` 或 SSH 以该用户登录）。
- **当前会话立即生效**：在该用户下执行 `newgrp docker`，再执行 `docker ps` 验证。

**验证**：以该用户执行 `docker ps` 无 permission denied 即表示生效；`usermod -aG docker` 为持久配置，重启后仍有效。

---

## 结构示意

```
┌─────────────────────────────────────────────────────────────┐
│ 宿主机                                                        │
│  1200 → rsshub │ 25501 → subconverter（栈内） │ Clash 不映射   │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│ rss-stack-rsshub │────▶│ rss-stack-redis  │     │ rss-stack-subconverter│
│ 1200             │     │ 6379             │     │ 25500（宿主机 25501）  │
└────────┬─────────┘     └──────────────────┘     └──────────┬──────────┘
         │ PROXY_HOST=clash-with-ui:7890                     │
         ▼                                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ rss-stack-clash-with-ui（clash-aio 构建）  代理 7890 / 控制 9090 仅内网   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 一、构建说明

### 1.1 克隆与子项目（RSSHub、clash-aio）

本仓库将 **RSSHub** 与 **clash-aio** 作为 git submodule，默认路径分别为 `./RSSHub`、`./clash-aio`。

- **首次克隆**：`git clone --recurse-submodules <rss-repo-url>`，或克隆后执行 `git submodule update --init --recursive`。
- **更新子项目**：在 rss 根目录执行 `git submodule update --remote RSSHub` 或 `git submodule update --remote clash-aio`；若 RSSHub 使用自己的 fork，可进入 `RSSHub` 后 `git pull upstream master` 再回到 rss 提交新 submodule commit。
- **若使用本机其他路径**：在 `.env` 中设置 `RSSHUB_PATH=../RSSHub`、`CLASH_AIO_PATH=../clash-aio` 等。

### 1.2 环境准备（.env）

- 复制 `.env.stack.example` 为 `.env`，填写：
  - **RAW_SUB_URL**：Clash 订阅链接（必填）。
  - **RSSHUB_PATH**：默认 `./RSSHub`（submodule）。
  - **CLASH_AIO_PATH**：默认 `./clash-aio`（submodule）。
  - 可选 **BUILD_PROXY**：构建时代理，如 `http://host.docker.internal:7890`。
  - 可选 **BILIBILI_COOKIE_<uid>**、**WEIBO_COOKIES** 等，见 [RSSHub 官方文档](https://docs.rsshub.app/guide/)。B 站 Cookie 推荐：将 Cookie 存于 `cookie/` 目录后执行 `./scripts/apply-bilibili-cookie.sh --uid <uid>`（本地）或 `--remote`（远程），见 [docs/bilibili-cookie-docker.md](docs/bilibili-cookie-docker.md)。

**预检查脚本**：执行 `./scripts/stack-pre-install.sh` 可自动创建 `.env`（若缺失）、检测子项目路径；`stack-build-and-up.sh` 会先调用该脚本（可通过 `SKIP_PRE_INSTALL=1` 跳过）。

### 1.3 一键构建并启动

在 **rss 项目根目录** 执行：

```bash
./scripts/stack-build-and-up.sh
```

脚本会：执行 pre-install 检查 → 初始化子项目（若未初始化）→ 加载 `.env` 并校验路径 → 从子项目构建 clash-with-ui 与 rsshub 镜像 → 启动四个容器 → 等待 RSSHub 端口 1200 就绪。

### 1.4 仅启动（已构建过）

若镜像已存在，只需启动（需 Docker Compose V2）：

```bash
# 若未在 .env 中设置，需先 export
export RSSHUB_PATH=./RSSHub CLASH_AIO_PATH=./clash-aio
docker compose -f docker-compose.stack.yml up -d
```

### 1.5 仅重新构建

```bash
export RSSHUB_PATH=./RSSHub CLASH_AIO_PATH=./clash-aio   # 若需
docker compose -f docker-compose.stack.yml build
```

### 1.6 从零构建与系统性测试

用于一次性验证「停止全部容器 → 前置检查 clash-aio → 先启动 Clash → 再启动 RSS → 整体验证」的完整链路。脚本需在 **rss 项目根目录** 执行（Git Bash 或 WSL）。

- **停止所有相关容器**（stack、默认 compose、独立 clash-aio compose）：执行 `./scripts/stack-down.sh`（一键退出）或 `./scripts/stack-stop-all.sh`。

- **从零构建并分步启动 + 整体验证**（系统性测试入口，跑通即表示测试通过）：
  ```bash
  ./scripts/stack-from-zero.sh
  ```
  流程：调用 stack-stop-all.sh → stack-pre-install.sh → 构建 → 先 `up -d subconverter clash-with-ui` 并等待就绪 → 再 `up -d redis rsshub` 并等待 1200 → 调用 stack-verify.sh。

- **仅做整体验证**（检查 RSSHub 1200、Subconverter 25501，可选 Clash 容器）：
  ```bash
  ./scripts/stack-verify.sh
  ```
  退出码 0 表示通过，非 0 表示未通过。

---

## 二、使用说明（如何用 RSSHub 获取 RSS）

RSSHub **通过 URL 提供订阅**，无需在后台“添加订阅列表”。

1. **基地址**：本栈 RSSHub 地址为 **`http://127.0.0.1:1200`**（或你映射的域名/端口）。
2. **订阅方式**：在任意 RSS 阅读器（Feedly、Inoreader、Fluent Reader 等）中「添加订阅」，填入 **`http://127.0.0.1:1200/<路由路径>`** 即可。
3. **路由路径从哪查**：[RSSHub 官方文档](https://docs.rsshub.app)（按站点与类型查路径与示例）。
4. **需要登录的路由**（如 B 站关注、微博时间线）：在 `.env` 中配置对应 Cookie 后重启 rsshub 容器，再在阅读器中添加上述格式的 URL 即可。

在 FOLO 或其它 RSS 阅读器中添加订阅源的详细步骤（含国内/国外示例与 Cookie 配置）见 [docs/folo-add-feeds.md](docs/folo-add-feeds.md)。更多参数（过滤、全文等）见 [docs.rsshub.app/parameter](https://docs.rsshub.app/parameter)。

---

## 三、环境变量摘要

| 变量 | 说明 |
|------|------|
| `RSSHUB_PATH` | RSSHub 子项目目录路径，默认 `./RSSHub` |
| `CLASH_AIO_PATH` | clash-aio 子项目目录路径，默认 `./clash-aio` |
| `RAW_SUB_URL` | Clash 订阅地址（clash-with-ui 启动时拉取） |
| `BUILD_PROXY` | 可选，构建时代理，如 `http://host.docker.internal:7890` |
| `PROXY_PROTOCOL` / `PROXY_HOST` / `PROXY_PORT` | 已在 compose 中设为 `http` / `clash-with-ui` / `7890`，一般无需改 |
| `PROXY_URL_REGEX` | 可选，限定走代理的 URL 正则；仅国外示例：`(youtube\|twitter\|telegram\|github\.com)` |
| `BILIBILI_COOKIE_<uid>` | Bilibili Cookie，见 [RSSHub 官方文档](https://docs.rsshub.app/guide/) |
| `WEIBO_COOKIES` | 微博 Cookie |

更多变量见 [RSSHub 文档](https://docs.rsshub.app/guide/)。

---

## 四、安全与资源

- **网络**：仅 RSSHub 的 1200、subconverter 的 25501 映射到宿主机；Clash 的 7890/9090 不映射，仅容器内网访问。
- **敏感信息**：Cookie、订阅链接等仅放在 `.env`，不提交到版本库。
- **资源**：Redis 使用 `redis:alpine`；可选在 `docker-compose.stack.yml` 中为各服务设置 `deploy.resources.limits.memory`（例如 RSSHub 256–512MB、Redis 64–128MB），避免单容器占满宿主机。

---

## 五、故障排查

- **端口冲突**：确保 1200、25501 未被占用（栈内 subconverter 宿主机端口为 25501）。
- **容器名冲突**：栈内容器名为 `rss-stack-*`，与独立运行的 clash-aio 不冲突。
- **RSSHub 无法访问外网**：确认 rss-stack-clash-with-ui 已启动且 `RAW_SUB_URL` 有效；查看日志：`docker compose -f docker-compose.stack.yml logs rss-stack-clash-with-ui` 或 `docker logs rss-stack-clash-with-ui`。
- **RSSHub 未就绪**：`docker logs rss-stack-rsshub`。
- **Cookie 失效**：参考 [RSSHub 官方文档](https://docs.rsshub.app/guide/) 重新获取并更新 `.env` 后重启 rsshub 容器。
- **构建很慢或镜像过大**：rsshub 镜像从子项目 `RSSHub` 构建，构建上下文在子项目内；可选设置 `BUILD_PROXY` 加速拉包。

---

## 五.1 公网访问与端口暴露

栈内 RSSHub 已映射到宿主机 `0.0.0.0:1200`。若公网无法访问，常见原因：（1）云安全组/防火墙未放行 TCP 1200，需在控制台添加入站规则；（2）若仅通过 Nginx/OpenResty 暴露 80/443，需在反向代理中配置到 `proxy_pass http://127.0.0.1:1200`。

**不暴露 1200 时的访问方式**：本机使用 SSH 本地端口转发后访问，例如 `ssh -L 1200:127.0.0.1:1200 用户@服务器`，再在浏览器打开 `http://127.0.0.1:1200`。

---

## 六、离线/无 Docker Hub 环境与构建失败时的备选流程

当目标服务器无法访问 Docker Hub，或 CI/远程构建失败时，可在**本机**完成构建、打包、上传，在服务器上加载后启动。

### 6.1 本机：打包镜像（推荐）

在 **rss 项目根目录** 执行（需已配置 `.env` 与子项目 RSSHUB_PATH、CLASH_AIO_PATH，可选 BUILD_PROXY 加速）：

```bash
./scripts/stack-images-pack.sh
```

脚本会：拉取 subconverter、redis → 构建 clash-with-ui 与 rsshub → 将四个镜像 `docker save` 为单一 tar。**若本地已运行过栈、镜像已存在**，可设 `SKIP_BUILD=1` 仅打包不拉取不构建。输出默认为项目根目录下的 `rss-stack-images.tar`（可通过 `STACK_IMAGES_TAR` 覆盖），已加入 `.gitignore`。

### 6.2 上传到服务器

**一键打包并上传**（推荐）：在 rss 根目录执行：

```bash
./scripts/stack-upload-to-server.sh
```

脚本会依次：调用 `stack-images-pack.sh`（输出到项目内 `rss-stack-images.tar`）→ scp 到 `REMOTE_USER@REMOTE_HOST` 家目录 → ssh 执行 mv 到 `REMOTE_ALCHEMY_DIR` 并以 alchemy 用户 `docker load`。默认 `REMOTE_USER=leonli`、`REMOTE_HOST=moicen.com`、`REMOTE_ALCHEMY_DIR=/home/alchemy/RSS`，可通过环境变量覆盖。若 tar 已存在只需重新上传，可设 `SKIP_PACK=1`。

**仅上传已有 tar**（手动）：将项目内的 `rss-stack-images.tar` 上传到服务器，例如：

```bash
scp rss-stack-images.tar <用户>@<服务器>:/tmp/
# 或传到 alchemy 目录后 load，见 6.3
```

### 6.3 服务器：加载镜像并启动

登录服务器并进入 rss 项目根目录后，按顺序执行：

1. **Docker 权限**：确认当前用户（如 alchemy）有权限访问 Docker（`docker ps` 无 permission denied）。若无，需管理员执行 `sudo usermod -aG docker <用户>` 后该用户重新登录。

2. **加载镜像**（将上传的 tar 解压引入 Docker，必须在启动前完成）：  
   默认从 `/tmp/rss-stack-images.tar` 读取；若 tar 在 alchemy 目录（如本地上传脚本所放位置）：
   ```bash
   export STACK_IMAGES_TAR=/home/alchemy/RSS/rss-stack-images.tar
   ./scripts/stack-images-load.sh
   ```
   或使用默认路径：`./scripts/stack-images-load.sh`（即 `docker load -i /tmp/rss-stack-images.tar`）。

3. **（可选）Cookie 配置**：若需 B 站关注/动态等路由，在本机执行 `./scripts/apply-bilibili-cookie.sh --uid <uid> --remote`（需 `cookie/bilibili_cookies.py` 或 `cookie/bilibili.txt`），将 Cookie 合并到服务器 `.env` 并重启 rsshub；微博执行 `./scripts/apply-weibo-cookie.sh --remote`。或登录服务器后编辑 `.env` 添加 `BILIBILI_COOKIE_<uid>=...` / `WEIBO_COOKIES=...` 再执行 `docker compose -f docker-compose.stack.yml up -d rsshub`。详见 [docs/bilibili-cookie-docker.md](docs/bilibili-cookie-docker.md)。

4. **停止旧容器**：若服务器上已有老版本栈在运行，需先停止再启动新服务，避免端口或容器名冲突：
   ```bash
   ./scripts/stack-down.sh
   ```
   或停止所有相关容器：`./scripts/stack-stop-all.sh`

5. **启动栈**：
   ```bash
   ./scripts/stack-build-and-up.sh
   ```
   此时镜像已通过步骤 2 引入，无需再从外网拉取或构建。

**一键执行**：若希望将步骤 2、4、5 合并，可在拉代码后执行：
```bash
./scripts/stack-server-update-and-start.sh
```
脚本会依次：检查 Docker 权限 → 在常见路径查找 tar 并加载（可选 `STACK_IMAGES_TAR`）→ 停止旧容器 → 启动栈。

### 6.4 验证

- **本机**：构建成功后用浏览器或 `curl` 访问服务器上的 RSSHub（如 `http://<服务器>:1200/`），确认可访问。
- **服务器**：在服务器上执行 `curl ipinfo.io` 可确认出网地区（例如非中国大陆则代理/出网正常）；或执行 `./scripts/stack-server-check.sh` 做本机端口与出网自检。

### 6.5 仅拉取基础镜像（可选）

若只需预置**上游基础镜像**（如 subconverter、redis、node 等）而不构建 rsshub/clash-with-ui，可参考与 rss 仓库同级的脚本（例如 `pull-save-upload-images.sh`）：拉取指定镜像 → `docker save` → scp 到服务器 → 在服务器上 `docker load`。完整栈仍建议使用 6.1 的 `stack-images-pack.sh`。
