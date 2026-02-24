# RSSHub 容器化部署计划

**本计划已实施。** 当前部署以 [DEPLOYMENT-STACK.md](DEPLOYMENT-STACK.md) 与 `docker-compose.stack.yml` 为准，资源限制等见 DEPLOYMENT-STACK 第四节。

---

本文档描述在 Linux VPS 上通过容器化构建「个人情报局」抓取层的部署计划：容器化 RSSHub、容器化代理、分流策略、Cookie 配置，以及安全与稳定性要求。

**约束**：VPS 内存有限，优先采用 **Docker + Alpine** 等轻量镜像，并对各服务做内存与可选性优化（见下文第 2 节与第 2.1 节）。

---

## 1. 计划依据：基于 RSSHub 的部署方案

- **选型**：采用官方镜像 `diygod/rsshub:latest` 或自建 `rss` 项目对应的镜像（若自建则建议基于 `node:alpine` 多阶段构建以减小体积与内存占用；环境变量与本仓库 `lib/config.js` 及 RSSHub 官方文档一致）。
- **运行形态**：RSSHub 以容器运行，依赖项（Redis、代理、可选无头浏览器）同样容器化，通过 Docker Compose 编排；在内存紧张时无头浏览器设为可选。
- **配置来源**：RSSHub 通过环境变量驱动（见分析文档中的 `lib/config.js` / `lib/config.ts`），计划中的 `docker-compose` 与 `.env` 需与之对齐。

---

## 2. 容器化 RSSHub 与容器化代理（Alpine / 低内存优先）

- **RSSHub 容器**：使用 `diygod/rsshub:latest`（或自建时基于 `node:alpine` 构建），暴露端口 `1200`，挂载仅限必要配置；不挂载代码卷。建议设置内存上限（见 5.2）。
- **代理容器**：使用 `dreamacro/clash`（镜像本身较小），将订阅生成的 `config.yaml` 挂载进容器，暴露 `mixed-port`（如 `7890`）；不映射到 host，仅内网访问。
- **其他容器（尽量 Alpine / 轻量）**：
  - **Redis**：**必须**使用 `redis:alpine`，体积与内存占用远小于默认标签；RSSHub 配置 `CACHE_TYPE=redis`、`REDIS_URL` 指向该容器。建议设置 `maxmemory` 与淘汰策略（如 `allkeys-lru`）避免撑满内存。
  - **Browserless/Chrome（可选）**：仅当需要「必须浏览器渲染」的路由（如部分反爬严格的站）时再启用；Chrome 类容器内存占用大（通常数百 MB～1GB+）。若不订阅此类路由，可不部署该服务，且不配置 `PUPPETEER_WS_ENDPOINT`，可显著节省内存。
- **编排**：单一 `docker-compose.yml` 定义上述服务；RSSHub 仅 `depends_on` Redis 与代理；Browserless 若启用再加入依赖。代理与 RSSHub 同网，使用服务名（如 `clash`）通信。

### 2.1 低内存与 Alpine 优化建议

| 组件        | 镜像/建议 | 说明 |
|-------------|-----------|------|
| Redis       | `redis:alpine` | 必选；缓存核心，Alpine 版体积与内存占用小。 |
| Clash       | `dreamacro/clash` | 保持；本身为单二进制，资源占用较低。 |
| RSSHub      | `diygod/rsshub:latest` 或自建 `node:alpine` | 官方镜像非 Alpine；自建时可多阶段构建基于 Alpine。 |
| Browserless | 可选      | 仅在有明确需求时启用；或使用 `browserless/chrome` 并严格限制内存与并发。 |

- **可选方案**：若 VPS 内存非常紧张（如 &lt;1GB 可用），可先只跑 **RSSHub + Redis(Alpine) + Clash**，不启 Browserless；大部分路由不依赖无头浏览器即可工作。后续若有需要再单独启用 Browserless 并设 `deploy.resources.limits.memory`。
- **Swap**：在宿主机上配置适量 swap（如 512MB～1GB）可降低 OOM 风险，但会牺牲部分性能；仅作兜底，优先仍靠限制容器内存与精简服务。

---

## 3. 国外信息源走容器内代理

- **策略**：仅国外源经代理，国内源直连，兼顾速度与可访问性。
- **实现**：
  - 在 RSSHub 环境变量中配置代理为容器内代理服务，例如：
    - `PROXY_PROTOCOL=http`
    - `PROXY_HOST=clash`（Compose 服务名）
    - `PROXY_PORT=7890`
  - 使用 RSSHub 支持的「按路由走代理」策略（若当前版本支持）：设置 `PROXY_STRATEGY=on_proxy_routes`（或等价选项），使仅配置为走代理的国外路由（如 YouTube、Twitter）使用代理，其余直连。
  - 若版本无该策略，则通过 `PROXY_URL_REGEX` 或文档中其它方式限定代理生效的域名/路径，避免国内站被误走代理。
- **代理侧**：保证 Clash 配置中 `mixed-port` 为 `7890`，与上述端口一致；不对外暴露 7890，仅 Docker 网络内访问。

---

## 4. Cookie 配置以访问国内站点

- **目的**：解决国内站反爬、登录态或限流（如 B 站、微博、知乎等），提高抓取成功率与稳定性。
- **方式**：通过环境变量向 RSSHub 注入 Cookie，与本仓库 `lib/config.js` 及 RSSHub 官方文档的约定一致：
  - **Bilibili**：`BILIBILI_COOKIE_1`（或 `BILIBILI_COOKIE_6` 等）填入 `SESSDATA` 等所需字段；多账号可配置多个 `BILIBILI_COOKIE_*` 轮询。
  - **微博**：`WEIBO_COOKIES` 填入从移动端/网页端提取的 Cookie（如含 `SUB` 等）。
  - **其它站点**：按 RSSHub 文档为对应路由配置 `*_COOKIE*` 或 `*_COOKIES` 环境变量。
- **安全**：Cookie 仅通过环境变量或 Docker Secrets 注入，不写入代码或挂载文件；`.env` 与 `docker-compose.yml` 不提交含真实 Cookie 的版本，使用 `.env.example` 模板。

---

## 5. 安全与稳定性要求

### 5.1 安全

- **网络**：RSSHub 与 Redis、Clash（及可选 Browserless）仅在内网通信；仅 RSSHub 端口（如 1200）对宿主机或反向代理暴露；Clash 的 7890 不映射到 host。
- **敏感信息**：Cookie、API Key、代理认证等仅放在 `.env` 或 Docker Secrets 中，并加入 `.gitignore`；生产环境禁止在日志或错误页中输出 Cookie/Token。
- **访问控制**：若公网暴露 RSSHub，建议通过 Nginx/Caddy 反向代理并配置 `ACCESS_KEY` 或 HTTP Basic Auth（RSSHub 支持），或 IP 白名单，限制未授权访问。
- **镜像与依赖**：使用官方或可信镜像标签（如 `diygod/rsshub:latest`），定期更新；避免在容器内以 root 长期运行（若镜像支持非 root 用户则优先使用）。

### 5.2 稳定性与低内存约束

- **重启策略**：所有服务 `restart: always`（或 `unless-stopped`），宿主机重启后自动拉起。
- **缓存**：必须启用 Redis（`CACHE_TYPE=redis`、`REDIS_URL` 正确），并使用 `redis:alpine`；可在 Redis 配置中设置 `maxmemory` 与 `maxmemory-policy allkeys-lru`，避免缓存撑满内存。
- **资源限制（低内存必设）**：在 `docker-compose.yml` 中为各服务设置 `deploy.resources.limits`，防止单服务占满宿主机；建议参考值（可按 VPS 实际内存调整）：
  - **RSSHub**：memory 约 256～512MB；
  - **Redis**：memory 约 64～128MB（Alpine 足够）；
  - **Clash**：memory 约 64～128MB；
  - **Browserless**（若启用）：memory 约 512MB～1GB，并限制并发，避免多实例同时跑。
- **健康检查**：为 RSSHub 配置 `healthcheck`（如 GET `/` 或 `/api/health`），便于编排器或监控判断服务是否可用。
- **日志**：统一使用 Docker 日志驱动，控制日志量（如 `LOGGER_LEVEL`）；避免将敏感信息写入日志。

---

## 6. 实施步骤小结

| 步骤 | 内容 |
|------|------|
| 1 | 在 VPS 上创建目录（如 `~/rsshub-stack`），准备 Clash 配置文件并重命名为 `clash.yaml`，确保 `mixed-port: 7890`。 |
| 2 | 编写 `docker-compose.yml`：优先使用 Alpine/轻量镜像（Redis 用 `redis:alpine`）；定义 clash、rsshub、redis，Browserless 按需可选；为各服务设置 `deploy.resources.limits`（内存见 5.2）；RSSHub 配置 `REDIS_URL`、代理变量及 `PROXY_STRATEGY`，仅在使用 Browserless 时配置 `PUPPETEER_WS_ENDPOINT`；Cookie 等敏感项使用 `.env`。 |
| 3 | 从浏览器安全提取并配置 Bilibili、微博等 Cookie 到 `.env`，不提交到版本库。 |
| 4 | 执行 `docker-compose up -d`，验证国内源（如 `/bilibili/user/video/xxx`）与国外源（如 `/youtube/c/xxx`）均可正常返回 RSS。 |
| 5 | 按「安全与稳定性」要求检查网络暴露、访问控制、内存限制与健康检查，并定期更新镜像与依赖。 |

---

## 7. 与参考方案的对应关系

- **分流抓取**：通过容器化 Clash + RSSHub 的 `PROXY_*` 与 `PROXY_STRATEGY`（或等价配置）实现国外走代理、国内直连。
- **身份伪装（Cookie）**：通过环境变量为 Bilibili、微博等国内站注入 Cookie，提升抓取成功率。
- **输出**：RSSHub 输出标准 RSS/Atom/JSON，可与 Obsidian、Templater、Python 脚本等下游「情报处理」流程衔接。

本计划不包含具体 `docker-compose.yml` 或 `.env.example` 的完整书写；实施时以本仓库 `lib/config.js`、`.env.stack.example` 及 RSSHub 官方部署文档为准，并在本计划的**安全、稳定性与低内存（Docker + Alpine 优先）**约束下编写与运维。
