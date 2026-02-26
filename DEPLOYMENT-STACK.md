# RSS + Clash 栈部署说明

本栈将 RSSHub（本仓库自建镜像）、Redis、Clash（由 clash-aio 项目构建）与 Subconverter 统一编排：RSSHub 通过内网使用 Clash 代理访问外网，国内源直连；Cookie 等通过环境变量配置。

### 快速开始

1. 克隆并初始化 submodule：`git clone --recurse-submodules <rss-repo-url>`，或克隆后执行 `git submodule update --init clash-aio`。
2. 复制 `.env.stack.example` 为 `.env`，填写 **RAW_SUB_URL**（必填）及可选 CLASH_AIO_PATH、Cookie。
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
| `stack-images-pack.sh` | 本机拉取/构建栈镜像并打包为 tar（用于离线部署） |
| `stack-images-load.sh` | 服务器从 tar 加载镜像（用于离线部署） |
| `stack-server-check.sh` | 服务器本机检查 1200/25501、Clash 7890、本机出网 ipinfo |

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

### 1.1 克隆与 clash-aio（submodule）

本仓库将 **clash-aio 作为 git submodule** 放在 `./clash-aio`，默认即用该路径，无需再配 CLASH_AIO_PATH。

- **首次克隆**：`git clone --recurse-submodules <rss-repo-url>`，或克隆后执行 `git submodule update --init clash-aio`。
- **若使用本机其他位置的 clash-aio**：在 `.env` 中设置 `CLASH_AIO_PATH=../clash-aio` 或 `../../Proxy/clash-aio` 等任意有效路径即可。

### 1.2 环境准备（.env）

- 复制 `.env.stack.example` 为 `.env`，填写：
  - **RAW_SUB_URL**：Clash 订阅链接（必填）。
  - **CLASH_AIO_PATH**：默认 `./clash-aio`（submodule）；若 clash-aio 在别处，改为对应相对或绝对路径。
  - 可选 **BUILD_PROXY**：构建时代理，如 `http://host.docker.internal:7890`。
  - 可选 **BILIBILI_COOKIE_<uid>**、**WEIBO_COOKIES** 等，见 [docs/install/COOKIE.md](docs/install/COOKIE.md)。

**预检查脚本**：执行 `./scripts/stack-pre-install.sh` 可自动创建 `.env`（若缺失）、在常见位置检测 clash-aio 并写入 CLASH_AIO_PATH；`stack-build-and-up.sh` 会先调用该脚本（可通过 `SKIP_PRE_INSTALL=1` 跳过）。

### 1.3 一键构建并启动

在 **rss 项目根目录** 执行：

```bash
./scripts/stack-build-and-up.sh
```

脚本会：执行 pre-install 检查 → 加载 `.env` 并校验 CLASH_AIO_PATH → 构建 clash-with-ui 与 rsshub 镜像 → 启动四个容器 → 等待 RSSHub 端口 1200 就绪。

### 1.4 仅启动（已构建过）

若镜像已存在，只需启动（需 Docker Compose V2）：

```bash
# 若未在 .env 中设置，需先 export
export CLASH_AIO_PATH=/path/to/clash-aio
docker compose -f docker-compose.stack.yml up -d
```

### 1.5 仅重新构建

```bash
export CLASH_AIO_PATH=/path/to/clash-aio   # 若需
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
3. **路由路径从哪查**：
   - 官方路由文档：[docs.rsshub.app](https://docs.rsshub.app)（按站点与类型查路径与示例）。
   - 示例：B 站用户投稿路径为 `/bilibili/user/video/:uid`，则订阅地址为 `http://127.0.0.1:1200/bilibili/user/video/2267573`；知乎热榜为 `http://127.0.0.1:1200/zhihu/hotlist`。
4. **需要登录的路由**（如 B 站关注、微博时间线）：在 `.env` 中配置对应 Cookie 后重启 rsshub 容器，再在阅读器中添加上述格式的 URL 即可。

更多参数（过滤、全文等）见 [docs/parameter](https://docs.rsshub.app/parameter) 或本仓库 `docs/parameter.md`。

---

## 三、环境变量摘要

| 变量 | 说明 |
|------|------|
| `CLASH_AIO_PATH` | clash-aio 目录路径，用于构建与 subconverter 卷挂载 |
| `RAW_SUB_URL` | Clash 订阅地址（clash-with-ui 启动时拉取） |
| `BUILD_PROXY` | 可选，构建时代理，如 `http://host.docker.internal:7890` |
| `PROXY_PROTOCOL` / `PROXY_HOST` / `PROXY_PORT` | 已在 compose 中设为 `http` / `clash-with-ui` / `7890`，一般无需改 |
| `PROXY_URL_REGEX` | 可选，限定走代理的 URL 正则；仅国外示例：`(youtube\|twitter\|telegram\|github\.com)` |
| `BILIBILI_COOKIE_<uid>` | Bilibili Cookie，见 [COOKIE.md](docs/install/COOKIE.md) |
| `WEIBO_COOKIES` | 微博 Cookie |

更多变量见 `lib/config.js` 或 [docs/install/README.md](docs/install/README.md)。

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
- **Cookie 失效**：见 [docs/install/COOKIE.md](docs/install/COOKIE.md) 重新获取并更新 `.env` 后重启 rsshub 容器。
- **构建很慢或镜像过大**：确认 [.dockerignore](.dockerignore) 已排除 `clash-aio`、`.env*` 等，避免进入 rsshub 构建上下文。

---

## 五.1 公网访问与端口暴露

栈内 RSSHub 已映射到宿主机 `0.0.0.0:1200`。若公网无法访问，常见原因：（1）云安全组/防火墙未放行 TCP 1200，需在控制台添加入站规则；（2）若仅通过 Nginx/OpenResty 暴露 80/443，需在反向代理中配置到 `proxy_pass http://127.0.0.1:1200`。

**不暴露 1200 时的访问方式**：本机使用 SSH 本地端口转发后访问，例如 `ssh -L 1200:127.0.0.1:1200 用户@服务器`，再在浏览器打开 `http://127.0.0.1:1200`。

---

## 六、离线/无 Docker Hub 环境

当目标服务器无法访问 Docker Hub 时，可在本机（可访问外网或代理）拉取/构建镜像并打包，上传到服务器后加载再启动。

### 6.1 本机：打包镜像

在 **rss 项目根目录** 执行（需已配置 `.env` 与 CLASH_AIO_PATH，可选 BUILD_PROXY 加速）：

```bash
./scripts/stack-images-pack.sh
```

脚本会：拉取 `tindy2013/subconverter:latest`、`redis:alpine` → 使用 `docker compose -f docker-compose.stack.yml build` 构建 clash-with-ui 与 rsshub → 将四个镜像 `docker save` 为单一 tar。输出路径由环境变量 `STACK_IMAGES_TAR` 指定，未设置时默认为项目根目录下的 `rss-stack-images.tar`（或上级目录，见脚本说明）。脚本结束时会打印生成的 tar 路径及建议的 scp 命令。

### 6.2 上传到服务器

将 tar 上传到服务器 **/tmp**，便于多用户访问。示例：

```bash
scp rss-stack-images.tar <用户>@<服务器>:/tmp/
```

上传后在服务器上设置权限（使其他用户可读）：

```bash
chmod 644 /tmp/rss-stack-images.tar
```

### 6.3 服务器：加载镜像并启动

登录服务器并进入 rss 项目根目录后：

1. **加载镜像**（默认从 `/tmp/rss-stack-images.tar` 读取，可通过环境变量 `STACK_IMAGES_TAR` 覆盖）：
   ```bash
   ./scripts/stack-images-load.sh
   ```
   或直接：`docker load -i /tmp/rss-stack-images.tar`

2. **启动栈**：
   ```bash
   ./scripts/stack-build-and-up.sh
   ```
   此时镜像已存在，无需再从外网拉取。

### 6.4 验证

- **本机**：构建成功后用浏览器或 `curl` 访问服务器上的 RSSHub（如 `http://<服务器>:1200/`），确认可访问。
- **服务器**：在服务器上执行 `curl ipinfo.io` 可确认出网地区（例如非中国大陆则代理/出网正常）；或执行 `./scripts/stack-server-check.sh` 做本机端口与出网自检。
