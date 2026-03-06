# RSSHub 故障排查（B 站 / 微博等）

本文梳理自建 RSSHub（如 ai.moicen.com/rss）常见问题：B 站 **412/503**、微博 **/weibo/friends** 报错等，并汇总 [RSSHub 官方 issues](https://github.com/DIYgod/RSSHub/issues) 中的社区经验。B 站完整 Cookie 配置见 [bilibili-cookie-docker.md](bilibili-cookie-docker.md)。

---

## 一、问题现象

- 订阅 **UP 主投稿**：`/bilibili/user/video/<uid>` 或 **用户关注视频动态**：`/bilibili/followings/video/<uid>` 时，RSSHub 返回 **503** 或页面报错。
- 服务器日志中可见：`FetchError: [GET] "https://space.bilibili.com/<uid>": 412 Precondition Failed`，或请求 `api.bilibili.com` / `api.vc.bilibili.com` 时 412、fetch failed、Cookie 已过期（code -6 / 4100000）等。
- 偶发：`TypeError: Cannot read properties of undefined (reading 'pages')`（多为某条视频为课程/收费/已删除等特殊类型，见 [RSSHub #19893](https://github.com/DIYgod/RSSHub/issues/19893)）。

---

## 二、原因概览

| 原因 | 说明 |
|------|------|
| 未配置或 Cookie 与路由 uid 不一致 | `BILIBILI_COOKIE_<uid>` 中的 uid 必须是**你本人** B 站账号 UID；`/followings/video/:uid` 的 uid 必须与某条已配置的 `BILIBILI_COOKIE_<uid>` 一致，否则该路由会报「缺少对应 uid 的 Cookie」或 412（[#19633](https://github.com/DIYgod/RSSHub/issues/19633)、[#20406](https://github.com/DIYgod/RSSHub/issues/20406)）。 |
| Cookie 过期或被限流 | B 站 Cookie 有效期有限；社区反馈即使用自己的 Cookie、访问量很小，也可能在较短时间内被限流或判为失效（[#20406](https://github.com/DIYgod/RSSHub/issues/20406)）。 |
| B 站风控 | 即使出口 IP 在大陆，B 站仍可能对请求头、Cookie、访问频率等做校验并返回 412；多 uid 路由轮流访问更容易触发风控。 |
| 全部流量走代理 | 若未设置 `PROXY_URL_REGEX`，RSSHub 所有请求（含 B 站）都经 Clash；若代理出口在海外，B 站易返回 412。 |
| 脚本变量冲突 | 早期 `apply-bilibili-cookie.sh` 使用只读变量 `UID`，在部分环境报错 `UID: readonly variable`，已改为 `BILIBILI_UID`。 |

---

## 三、解决方案（按推荐顺序）

### 3.1 配置 Cookie 且 uid 与路由一致

1. **获取 Cookie**：无痕窗口登录 bilibili.com，F12 → Application → Cookies → 复制为 `cookie/bilibili.txt` 或 `cookie/bilibili_cookies.py`（格式见 [bilibili-cookie-docker.md](bilibili-cookie-docker.md)）。
2. **确认本人 uid**：变量名应为 `BILIBILI_COOKIE_<你的B站账号uid>`（不是 UP 主的 uid）。若你的账号 uid 是 1282360，则配置 `BILIBILI_COOKIE_1282360`。
3. **部署到服务器**：在 rss 项目根目录执行  
   `./scripts/apply-bilibili-cookie.sh --uid 1282360 --remote`  
   会从 `cookie/` 生成配置、scp 到 moicen、合并到服务器 `.env` 并重启 rsshub。
4. **订阅与 uid 对应**：  
   - 使用 **用户关注视频动态** 时，URL 中的 uid 必须与上面配置的 uid 一致，例如只配了 `BILIBILI_COOKIE_1282360` 时，只能访问 `.../followings/video/1282360`，不能访问 `.../followings/video/501`。

### 3.2 国内直连 B 站（设置 PROXY_URL_REGEX）

若 RSSHub 所在服务器在大陆，希望 B 站请求直连、仅国外站走代理：

- 在服务器 `.env` 中取消注释并设置：  
  `PROXY_URL_REGEX=(youtube|twitter|telegram|github\.com|reddit)`  
  这样 `bilibili.com` 不匹配，直连访问。
- 修改后执行 `docker compose -f docker-compose.stack.yml up -d rsshub` 使配置生效。

### 3.3 优先用「用户关注视频动态」减少风控

- 订阅多个 UP 时，建议在 B 站先关注这些 UP，然后只订阅一条 **`/bilibili/followings/video/<你的uid>`**，可减少对 B 站的多路请求，降低 412 概率（参见 [RSSHub #20406](https://github.com/DIYgod/RSSHub/issues/20406)）。
- UP 投稿路由 `/bilibili/user/video/<up的uid>` 易触发风控，可作为备选。

### 3.4 降低请求频率

- 在服务器 `.env` 中设置 `CACHE_EXPIRE=600`（或 900），拉长路由缓存时间。
- 启用 filter 插件：`RSSHUB_PLUGIN_FILTER=true`；仍 412 时可在订阅 URL 后加 `?filterout=author`。

### 3.5 关于 /bilibili/check-cookie

- 部分 RSSHub 实例未暴露 `/bilibili/check-cookie`，访问会 404/NotFound，可忽略；Cookie 是否有效以实际订阅能否返回 200 为准。

### 3.6 followings/video 仍不可用时的排查

- **确认服务器 .env 中确有该 uid 的 Cookie**：例如访问 `.../followings/video/1282360` 时，服务器上必须有 `BILIBILI_COOKIE_1282360=...`（部署后可在服务器执行 `grep BILIBILI_COOKIE_1282360 .env` 确认）。
- **Cookie 过期或已被限流**：B 站可能短时间内就限流或令 Cookie 失效；建议**重新获取 Cookie**（无痕 + 手机扫码），更新 `cookie/` 后再次执行 `./scripts/apply-bilibili-cookie.sh --uid <你的uid> --remote`。
- **尝试 filter 参数**：在订阅 URL 后加 `?filterout=author`，并确保 `.env` 中已设置 `RSSHUB_PLUGIN_FILTER=true`（[#20406 用户反馈](https://github.com/DIYgod/RSSHub/issues/20406) 部分场景下可恢复可用）。
- **避免频繁刷新**：阅读器刷新间隔建议 ≥ 15～30 分钟；服务器端已设 `CACHE_EXPIRE=600` 时，同一路由 10 分钟内不会重复请求 B 站。
- **Puppeteer**：社区反馈仅开 Puppeteer、不配 Cookie 仍易被限制，推荐以配置 Cookie 为主（[#20406](https://github.com/DIYgod/RSSHub/issues/20406)）。

### 3.7 其他可选环境变量（RSSHub）

- **BILIBILI_EXCLUDE_SUBTITLES=true**：不抓取字幕，可避免部分视频（如课程/收费/已删除）导致的 `TypeError: Cannot read properties of undefined (reading 'pages')`（[#19893](https://github.com/DIYgod/RSSHub/issues/19893)、[PR #19834](https://github.com/DIYgod/RSSHub/pull/19834)）。若日志中出现该错误，可在服务器 `.env` 中增加此变量并重启 rsshub。

---

## 四、已知限制（来自 RSSHub issues）

- **followings/video 条数限制**：该路由依赖 B 站动态 API，在 `CACHE_EXPIRE` 时间内若关注列表更新超过约 20 条，可能漏更（[#20406](https://github.com/DIYgod/RSSHub/issues/20406)）。
- **风控无通用解法**：同一 Cookie、同一环境，有时 200 有时 412；限流后需隔一段时间再试或重新获取 Cookie。
- **UP 投稿路由**：`/bilibili/user/video/<up的uid>` 多路同时访问易触发风控；优先用单条 followings/video 可减轻问题（[#20406](https://github.com/DIYgod/RSSHub/issues/20406)）。

---

## 五、本栈相关脚本与文档

| 脚本/文档 | 说明 |
|-----------|------|
| [scripts/apply-bilibili-cookie.sh](../scripts/apply-bilibili-cookie.sh) | 从 cookie/ 生成 `BILIBILI_COOKIE_<uid>` 并合并到 .env；支持 `--local`/`--remote`、`--no-restart`。 |
| [scripts/upload-cookie-and-apply-remote.sh](../scripts/upload-cookie-and-apply-remote.sh) | 将 cookie/（B 站+微博）scp 到服务器、合并 .env、重启 rsshub，并清理微博 Redis 缓存；推荐远程更新 Cookie 时使用。 |
| [docs/bilibili-cookie-docker.md](bilibili-cookie-docker.md) | B 站 Cookie 获取、格式、多账号、一键部署及 412 风控建议。 |
| [docs/folo-add-feeds.md](folo-add-feeds.md) | FOLO 中添加订阅源，含 B 站、微博、Twitter、YouTube 等。 |

---

## 六、快速检查清单

- [ ] 已在 `cookie/` 下放置 `bilibili_cookies.py` 或 `bilibili.txt`，且 Cookie **完整**（含 SESSDATA、DedeUserID、bili_jct）；建议无痕 + 手机扫码重新获取。
- [ ] 执行过 `./scripts/apply-bilibili-cookie.sh --uid <你的uid> --remote`，且 **URL 中的 uid 与配置的 BILIBILI_COOKIE_<uid> 一致**（如 1282360 则仅能访问 followings/video/1282360）。
- [ ] 服务器 `.env` 中已设置 `PROXY_URL_REGEX`（仅国外站走代理）；已设 `CACHE_EXPIRE=600`、`RSSHUB_PLUGIN_FILTER=true`。
- [ ] 仍不可用时：重新取 Cookie 再部署一次；订阅 URL 后加 `?filterout=author`；必要时设 `BILIBILI_EXCLUDE_SUBTITLES=true` 并重启 rsshub。

---

## 七、RSSHub 官方 issues 参考

| Issue | 主题 | 要点 |
|-------|------|------|
| [#20406](https://github.com/DIYgod/RSSHub/issues/20406) | BiliBili 无法获取 UP 主投稿 412 | Cookie 需完整、uid 为自己账号；followings/video 可减轻风控；filterout=author + FILTER 插件；风控后重取 Cookie |
| [#19893](https://github.com/DIYgod/RSSHub/issues/19893) | 部分 up 主视频抓取失败 | 课程/收费/已删视频导致 pages 未定义；可设 BILIBILI_EXCLUDE_SUBTITLES=true |
| [#19633](https://github.com/DIYgod/RSSHub/issues/19633) | UP 主投稿 fetch failed | 需完整 Cookie、浏览器 User-Agent；自建并配置 Cookie 后测试 |
| [#19545](https://github.com/DIYgod/RSSHub/issues/19545) | UP 主动态 503 | BILIBILI_COOKIE_{uid} 为**自己**账号 uid；与 #18506 重复 |

---

## 八、微博 /weibo/friends 报错（503 或 userInfo undefined）

**成功经验**：使用 **m.weibo.cn** 的请求 Cookie（SUB、XSRF-TOKEN、_T_WM、M_WEIBOCN_PARAMS、SSOLoginState、WEIBOCN_FROM 等），整理到 `cookie/weibo_cookies.py` 后执行 `./scripts/upload-cookie-and-apply-remote.sh`，订阅即可正常。

参考 [RSSHub 微博相关 issues](https://github.com/DIYgod/RSSHub/issues?q=weibo)（如 [#20921](https://github.com/DIYgod/RSSHub/issues/20921)、[#20633](https://github.com/DIYgod/RSSHub/issues/20633)、[#20836](https://github.com/DIYgod/RSSHub/issues/20836)），常见原因与应对如下。

| 可能原因 | 说明与做法 |
|----------|------------|
| **Cookie 不完整或已失效** | 微博 API 在 Cookie 无效时返回的数据缺少 `data.userInfo`，RSSHub 读取时会报 `TypeError: Cannot read properties of undefined (reading 'userInfo')` 并返回 503。**必须**在 **[m.weibo.cn](https://m.weibo.cn)** 登录后获取 Cookie（不要仅从 weibo.com 或 passport.weibo.com 复制）：F12 → Application → Cookies 选 **m.weibo.cn**，或从 **Network** 任选请求查看 Request Headers 中的 Cookie。**SUB、XSRF-TOKEN** 在 m.weibo.cn 与 weibo.com 可能不同，须使用 m.weibo.cn 的请求 Cookie；建议同时包含 **SUBP、WBPSESS、ALF、_T_WM、M_WEIBOCN_PARAMS、SSOLoginState、WEIBOCN_FROM** 等，若有 **SCF** 则一并加入。整理为 `cookie/weibo_cookies.py` 或 `weibo.txt` 后执行 `./scripts/upload-cookie-and-apply-remote.sh`。Cookie 易在几分钟到几小时内失效，需定期更新。 |
| **服务器 IP 被微博限制** | 若 RSSHub 部署在海外 VPS，微博可能对 IP/地区限流或返回异常结构。可配置**国内代理**：在 `.env` 中设置 `PROXY_URI`（或本栈已有 Clash 时，通过 `PROXY_URL_REGEX` 让微博直连、仅国外站走代理；若服务器在海外，则需让微博请求走国内代理）。参见 [RSSHub 代理配置](https://docs.rsshub.app/zh/deploy/config#%E4%BB%A3%E7%90%86)、[#20836](https://github.com/DIYgod/RSSHub/issues/20836)。 |
| **缓存了无效数据** | 若曾用无效 Cookie 请求过，Redis 可能缓存了 `weibo:friends:login-user` 或 `weibo:user:index:undefined`。本栈在执行 `./scripts/upload-cookie-and-apply-remote.sh` 时会自动清理这两个 key；若未通过该脚本更新，可登录服务器执行：`docker compose -f docker-compose.stack.yml exec -T redis redis-cli DEL weibo:friends:login-user weibo:user:index:undefined`，再重试订阅。 |

**重要：微博是否走代理**  
本栈在 docker-compose 中为 RSSHub 配置了 `PROXY_HOST=clash-with-ui`、`PROXY_PORT=7890`。RSSHub 通过 **PROXY_URL_REGEX** 决定哪些请求走代理：**未设置时默认为 `.*`，即全部请求（含微博 m.weibo.cn）都走 Clash**。若 Clash 出口在海外，微博可能对出口 IP 限流或返回异常。  
**建议**：在服务器 `.env` 中设置 `PROXY_URL_REGEX=(youtube|twitter|telegram|github\.com|reddit)`（仅国外站走代理），让微博、B 站等国内站直连。修改后执行 `docker compose -f docker-compose.stack.yml up -d rsshub` 生效。

**操作顺序建议**：① 确认 `.env` 中已设 `PROXY_URL_REGEX`，避免微博走海外代理；② 用 **m.weibo.cn** 登录 → F12 → Application/Network 复制 **m.weibo.cn 的请求 Cookie**（SUB、XSRF-TOKEN 等须来自 m.weibo.cn）→ 整理为 `cookie/weibo_cookies.py` 或 `weibo.txt`；③ 执行 `./scripts/upload-cookie-and-apply-remote.sh`（会合并 .env、重启 rsshub、清理微博 Redis 缓存）；④ 若仍报 userInfo 错误，在服务器执行 `grep WEIBO_COOKIES /home/alchemy/RSS/rss/.env` 或 `docker compose -f docker-compose.stack.yml exec rsshub env | grep WEIBO` 确认变量已传入容器；⑤ 若服务器在海外且仍失败，配置国内代理后再试。

**订阅正常但图片/视频在阅读器内不显示**：微博 CDN（sinaimg.cn、weibocdn.com）有防盗链，阅读器直连易 403。在服务器 `.env` 中设置 `HOTLINK_TEMPLATE=https://images.weserv.nl?url=$${href_ue}` 与 `HOTLINK_INCLUDE_PATHS=/weibo` 后重启 rsshub（docker-compose 加载 .env 时须写 `$$` 才能把 `${href_ue}` 原样传给 RSSHub），可将微博描述中的图片重写为代理地址；视频因带有效期与防盗链，建议点击条目在浏览器中打开观看。详见 [RSSHub 图片处理](https://docs.rsshub.app/zh/deploy/config#图片处理)、[folo-add-feeds.md](folo-add-feeds.md) 微博小节，社区讨论见 [#10874](https://github.com/DIYgod/RSSHub/issues/10874)、[#20995](https://github.com/DIYgod/RSSHub/issues/20995)。
