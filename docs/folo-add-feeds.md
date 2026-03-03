# 在 FOLO 中添加订阅源

本文说明如何在本项目 RSSHub 实例下，于 FOLO（或任意 RSS 阅读器）中添加订阅源。RSSHub 基地址为 **https://ai.moicen.com/rss/**，订阅 URL = 基地址 + 路由路径。

**约定**：

- 部分站点**无需 Cookie**（如百度热搜、B 站热搜、YouTube 频道等），可直接添加订阅地址使用。
- 部分**需要 Cookie 或账号**（如 B 站关注/动态、微博、Twitter、YouTube 订阅列表等）；需在运行 RSSHub 的服务器上配置 `.env` 并重启 rsshub 容器。
- 本栈包含 clash-aio，RSSHub 通过内网代理访问国外站；非 RSSHub 所在的 VPS 本身可访问外网，访问 RSSHub 页面或 FOLO 时无需单独配置代理。

路由路径与参数以 [RSSHub 路由文档](https://rsshub.netlify.app/zh/routes) 为准。

---

## 一、验证 RSSHub 是否生效（无需 Cookie）

在 FOLO 或浏览器中打开以下地址，能返回 RSS/条目即表示 RSSHub 正常：

- **百度热搜**：`https://ai.moicen.com/rss/baidu/top`

已测试通过，可直接用作首次验证。

---

## 二、国内订阅源

### 2.1 微博

- **路由**：参考 [RSSHub 社交媒体路由](https://rsshub.netlify.app/zh/routes/social-media)，若官方文档中有「微博」小节（如用户时间线等），将示例中的域名替换为 `https://ai.moicen.com/rss` 即可。
- **Cookie**：微博路由通常需要 `WEIBO_COOKIES`。
  - 在**运行 RSSHub 的服务器**上，进入 rss 项目目录，编辑 `.env`，添加：`WEIBO_COOKIES=从浏览器/移动端复制的 Cookie 字符串`。
  - 获取方式：登录 weibo.com（或移动端），打开开发者工具 → Network → 任选请求 → 复制 Cookie 请求头。
  - **注意**：若当前使用的 RSSHub 子项目**未包含微博路由**（如本仓库 submodule 中无 weibo 相关路由），则需使用官方 RSSHub 或自建并启用微博路由；此处 Cookie 配置方法供自建实例使用。
- 微博防盗链可能导致 RSS 内图片无法显示；自建时可配置 `HOTLINK_TEMPLATE`、`HOTLINK_INCLUDE_PATHS`（见 RSSHub 部署文档）。

### 2.2 Bilibili

**不需 Cookie 的路由**（可直接在 FOLO 中添加）：

| 类型     | 订阅地址示例 |
|----------|--------------|
| 热搜     | `https://ai.moicen.com/rss/bilibili/hot-search` |
| UP 主投稿 | `https://ai.moicen.com/rss/bilibili/user/video/<uid>`（uid 从 UP 主页 URL 获取；易遇 412 风控，见下） |
| 用户关注视频动态 | `https://ai.moicen.com/rss/bilibili/followings/video/<你的uid>`（需 Cookie，推荐：先关注 UP，只订此一条可减少风控） |
| 综合热门 | `https://ai.moicen.com/rss/bilibili/popular/all` |
| 每周必看 | `https://ai.moicen.com/rss/bilibili/weekly` |

更多（分区、专栏等）见 [RSSHub Bilibili 路由](https://rsshub.netlify.app/zh/routes/social-media#bilibili)。若 UP 投稿或关注视频路由常返回 412/503，见 [bilibili-cookie-docker.md](bilibili-cookie-docker.md) 第六节与 [troubleshooting.md](troubleshooting.md)。

**需要 Cookie 的路由**（如 UP 主动态、关注动态、粉丝、收藏夹、稍后再看等）：

- **推荐**：将 Cookie 保存到项目 `cookie/` 目录（如 `cookie/bilibili_cookies.py` 或 `cookie/bilibili.txt`），在 rss 项目根目录执行：
  - 本地：`./scripts/apply-bilibili-cookie.sh --uid <uid>`（会合并到 `.env` 并重启 rsshub）
  - 远程服务器：`./scripts/apply-bilibili-cookie.sh --uid <uid> --remote`（通过 scp/ssh 合并到服务器 `.env` 并重启 rsshub，需配置 `REMOTE_USER`、`REMOTE_HOST`、`REMOTE_ALCHEMY_DIR`）
- 或手动：在运行 RSSHub 的机器上编辑 `.env`，添加 `BILIBILI_COOKIE_<uid>=<整段 Cookie>`，然后执行 `docker compose -f docker-compose.stack.yml up -d rsshub`。
- **获取 Cookie**：登录 bilibili.com → 开发者工具 Network → 任选 api.bilibili.com 请求 → 复制请求头 Cookie。**详细步骤与防封建议**见 [docs/bilibili-cookie-docker.md](bilibili-cookie-docker.md)。

---

## 三、国外订阅源

### 3.1 Twitter（X）

- **路由示例**：
  - 用户时间线：`https://ai.moicen.com/rss/twitter/user/<用户名>`
  - 关键词：`/twitter/keyword/<关键词>`
  - 列表：`/twitter/list/<id>/<name>`
  - 点赞：`/twitter/likes/<用户名>`
- **需要配置**：多数 Twitter 路由需在服务器 `.env` 中配置 `TWITTER_USERNAME` 与 `TWITTER_PASSWORD`（RSSHub 通过账号获取 token）。
  - 添加后重启 rsshub，再在 FOLO 中填入上述格式的订阅 URL。
  - 若出现 403 或限流，可能与 IP 或 token 失效有关，建议自建实例并定期更新 RSSHub。

### 3.2 YouTube

**不需 Cookie 的常用路由**：

| 类型     | 订阅地址示例 |
|----------|--------------|
| 频道     | `https://ai.moicen.com/rss/youtube/channel/<频道ID>` |
| 播放列表 | `https://ai.moicen.com/rss/youtube/playlist/<播放列表ID>` |
| 用户     | `https://ai.moicen.com/rss/youtube/user/<用户名>` |

也可使用 YouTube 官方 RSS，不经过 RSSHub：`https://www.youtube.com/feeds/videos.xml?channel_id=<频道ID>`。

**需要配置的路由**：如「订阅列表」`/youtube/subscriptions` 需配置 `YOUTUBE_CLIENT_ID`、`YOUTUBE_CLIENT_SECRET`、`YOUTUBE_REFRESH_TOKEN`、`YOUTUBE_KEY` 等，见 [RSSHub 部署文档](https://docs.rsshub.app/zh/config/)。一般订阅频道/播放列表无需 Cookie。

**观看与打开方式**：订阅源只提供视频链接，不提供视频流；画质与是否配置 Cookie 无关。若在 FOLO 内嵌播放画质不佳，建议点击条目链接到**默认浏览器**中打开 YouTube 页面观看。是否在浏览器新标签页打开由 FOLO 的「在外部浏览器打开」或类似设置决定，请在 FOLO 设置中查看。

---

## 四、如何添加与设置 Cookie

- **位置**：在**运行 RSSHub 的服务器**上，进入 rss 项目目录，编辑 `.env`（若不存在则从 `.env.stack.example` 复制一份再编辑）。
- **格式**：
  - Bilibili：`BILIBILI_COOKIE_<uid>=整段或 SESSDATA 等`
  - 微博：`WEIBO_COOKIES=整段 Cookie`
  - 其他站点：变量名一般为 `*_COOKIE*` 或 `*_COOKIES`，参考 [RSSHub 配置文档](https://docs.rsshub.app/zh/config/) 或本仓库 [.env.stack.example](../.env.stack.example)。
- **生效**：修改 `.env` 后执行 `docker compose -f docker-compose.stack.yml up -d rsshub`（或本栈使用的启动命令）重启 rsshub 容器。
- **安全**：勿将 `.env` 提交到版本库；生产环境勿在日志或公网暴露 Cookie。B 站 Cookie 的详细获取与防封说明见 [docs/bilibili-cookie-docker.md](bilibili-cookie-docker.md)。

---

## 五、参考链接

- [RSSHub 路由（中文）](https://rsshub.netlify.app/zh/routes)
- [RSSHub 配置说明](https://docs.rsshub.app/zh/config/)
- 本仓库：[DEPLOYMENT-STACK.md](../DEPLOYMENT-STACK.md)、[.env.stack.example](../.env.stack.example)
