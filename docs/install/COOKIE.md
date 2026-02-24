# Cookie 配置说明

部分路由需要登录态或 Cookie 以提升抓取成功率、规避限流。Cookie 仅通过**环境变量**注入（如部署时的 `.env`），不要写入代码或提交到版本库。

## 安全注意

- Cookie 仅放在 `.env` 或 Docker 的 `env_file` 中，并确保 `.env` 已加入 `.gitignore`。
- 不要将含真实 Cookie 的 `.env` 提交到 Git；生产环境不要在日志或错误页中输出 Cookie。

## Bilibili

- **变量名**：`BILIBILI_COOKIE_{uid}`，其中 `{uid}` 替换为对应用户的 uid，例如 `BILIBILI_COOKIE_2267573`。
- **多账号**：可配置多条 `BILIBILI_COOKIE_<uid>`，路由会按需使用对应 uid 的 Cookie。
- **获取方式**：
  1. 在浏览器登录 bilibili.com。
  2. 打开开发者工具（F12）→ Network 面板，刷新页面。
  3. 在 bilibili 域名下任选一请求，在 Request Headers 中找到 **Cookie**，复制整段。
  4. 视频/专栏类路由通常只需包含 `SESSDATA` 的片段；关注动态等路由建议复制整段 Cookie。
- 若 Cookie 过期，路由会报错提示“Cookie 已过期”，需重新按上述步骤获取并更新 `.env`。

## 微博

- **变量名**：`WEIBO_COOKIES`。
- **获取方式**：在移动端或网页端登录微博后，从浏览器开发者工具中找到对 weibo 域名的请求，复制 Request Headers 中的 Cookie（通常含 `SUB` 等字段）。

## 其他站点

更多站点的 Cookie / Token 配置见 [部署文档](./README.md) 中的「添加配置」及对应路由说明；变量名一般与 `lib/config.js` 中的键一致（如 `DOUBAN_COOKIE`、`ZHIHU_COOKIE` 等）。也可参考 [RSSHub 官方文档](https://docs.rsshub.app) 中对应路由的说明。
