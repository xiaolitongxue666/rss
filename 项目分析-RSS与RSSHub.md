# RSS 与 RSSHub 项目分析

本文档对工作区内的 **rss**（自建）与 **RSSHub**（参考）两个项目进行结构、层级、依赖与使用方式的分析。

---

## 1. 分析范围

- **rss**（自建）：`rss/` — 基于 RSSHub 的 JavaScript/Koa 分支，`package.json` 中 name 仍为 `rsshub`，入口为 `lib/index.js`，主逻辑在 `lib/`。
- **RSSHub**（参考）：`RSSHub/` — 官方 TypeScript/Hono 版本，入口为 `lib/index.ts`，主逻辑在 `lib/`，构建产物在 `assets/build/`、`dist/` 等。

---

## 2. 项目结构

### 2.1 rss 项目结构

```
rss/
├── lib/                    # 运行时主代码
│   ├── index.js            # 进程入口（cluster + app.listen）
│   ├── app.js              # Koa 应用、中间件挂载、路由挂载
│   ├── config.js           # 配置（dotenv + 环境变量）
│   ├── router.js           # 旧版路由（懒加载 require，大量 router.get）
│   ├── core_router.js      # 核心路由：/、/robots.txt
│   ├── protected_router.js # 需认证路由
│   ├── api_router.js       # API 路由（/api）
│   ├── v2router.js         # 从 lib/v2 扫描 router.js 聚合
│   ├── views/              # 模板：welcome.art, rss.art, atom.art, error.art, json.js
│   ├── middleware/         # onerror, header, utf8, cache, parameter, template, debug,
│   │                       # access-control, anti-hotlink, load-on-demand, api-template, api-response-handler
│   ├── utils/              # got, logger, parse-date, cache, puppeteer, rand-user-agent 等
│   ├── routes/             # 旧版路由实现（与 router.js 对应）
│   └── v2/                 # 新版路由：按站点分目录，每目录含 router.js + maintainer.js + radar.js + 具体 handler
├── test/                   # Jest 测试（router, middleware, utils, config）
├── scripts/                # workflow（build-radar, build-maintainer）、ansible、docker、docs-scraper
├── docs/                   # VuePress 文档（中英、install、joinus、分类路由文档）
├── package.json            # npm 脚本：dev(nodemon), start, build:radar, build:maintainer, jest
├── vercel.json             # 全部请求 -> /api/vercel.js
└── process.json            # 进程配置（若存在）
```

**请求与路由层级**：

- `index.js` 启动 Koa 应用（可选 cluster），监听端口或 Unix Socket。
- `app.js` 挂载中间件顺序：favicon → onerror → accessControl → debug → header → utf8 → apiTemplate → apiResponseHandler → template → antiHotlink → parameter → **core_router**（`/`、`/robots.txt`）→ **api_router**（`/api`）→ cache → **loadOnDemand**（动态挂载 v2 路由）→ **router**（旧版路由）→ **protected_router**（`/protected`）。
- 动态路由：`load-on-demand` 根据请求路径首段（如 `zhihu`）从 `v2router` 取对应模块，首次命中时 `mod(router)` 并 `mount('/zhihu', router.routes())`，实现按需挂载。

### 2.2 RSSHub 项目结构

```
RSSHub/
├── lib/
│   ├── index.ts            # 入口：cluster + @hono/node-server serve
│   ├── app.ts              # 仅做 request-rewriter 与 app-bootstrap 的 re-export
│   ├── app-bootstrap.tsx   # 实际创建并导出 Hono 应用（含静态、健康检查、API、registry 路由）
│   ├── server.ts           # 导出 app-bootstrap，供部分部署形态使用
│   ├── registry.ts         # 核心：directoryImport 或 assets/build 的 namespaces，Hono 按 namespace + route 注册
│   ├── config.ts           # 配置（dotenv + 类型化 ConfigEnvKeys）
│   ├── types.ts            # Category, DataItem, Data, Route, Namespace, Context 等
│   ├── views/              # TSX：rss, atom, json, error, layout, index
│   ├── middleware/         # trace, sentry, parameter, template 等
│   ├── utils/              # ofetch, got, cache, puppeteer, proxy, logger, parse-date 等（含 .test.ts）
│   ├── routes/             # 按站点/功能目录，每目录 namespace.ts + 各 route 的 path + handler
│   ├── shims/              # xxhash-wasm, sentry-node, dotenv-config 等
│   ├── worker.ts           # Worker 形态入口（导出 app.worker）
│   └── app.worker.tsx       # Cloudflare Worker 简化版应用
├── scripts/workflow/       # build-routes.ts, build-docs.ts（产出 assets/build/routes.js 等）
├── assets/build/           # 构建产物：routes.js, routes.json, radar-rules, maintainers, route-paths.ts
├── patches/                # 如 rss-parser 补丁
├── package.json            # type: module, tsx, tsdown 多配置, pnpm, engines ^22.20.0||^24
├── tsconfig.json           # paths @/* -> lib/*
├── tsdown*.config.ts       # 多种构建目标（lib, vercel, worker, container）
├── vercel.json             # framework: hono, rewrites
└── wrangler*.toml          # Worker/Container 部署
```

**请求与路由层级**：

- `index.ts` 使用 Node cluster，主进程 fork 子进程，子进程通过 `@hono/node-server` 的 `serve()` 以 `app.fetch` 处理请求。
- `app` 来自 `app.ts`，实际为动态导入的 `app-bootstrap.tsx` 的默认导出；`app-bootstrap.tsx` 中挂载静态、健康检查、metrics、robots、API 文档等，并引入 `registry.ts` 中按 namespace 注册的路由。
- `registry.ts`：开发态从 `lib/routes` 做 `directoryImport` 得到各 namespace/route 模块，生产/包态从 `assets/build/routes.js` 读取 namespaces；对每个 namespace 以 `app.basePath('/:namespace')` 注册子应用，再按 path 注册 GET 及 handler；handler 通过 `routeData.module()` 或 `routeData.handler` 懒加载。

---

## 3. 依赖关系

### 3.1 rss（CommonJS，Node ≥16）

- **运行时**：Koa、@koa/router、art-template、cheerio、got、dotenv、ioredis、lru-cache、puppeteer 系列、rss-parser、markdown-it、winston 等；路径别名 `@` 通过 `module-alias` 指向 `lib`。
- **路由与视图**：`router.js` 使用 `require(routeHandlerPath)` 懒加载；v2 通过 `require-all` 扫描 `lib/v2/**/router.js` 聚合到 `v2router`，再由 `load-on-demand` 在首次命中时 `mod(router)` 并 `mount`。
- **配置**：`config.js` 的 `value` 由 `calculateValue()` 从 `process.env` 计算（含 BILIBILI_COOKIE_*、缓存、代理、认证等）。

### 3.2 RSSHub（ESM，Node ^22.20.0||^24，pnpm）

- **运行时**：Hono、@hono/node-server、ofetch、cheerio、ioredis、puppeteer-real-browser/rebrowser、rss-parser、zod 等；路径别名 `@/*` 在 tsconfig 与构建中映射到 `lib/*`。
- **路由与视图**：由 `lib/registry.ts` 统一注册；开发态 `directoryImport('./routes')` 得到 namespace/route 模块，生产态读取 `assets/build/routes.js`；路由 handler 通过 `routeData.module()` 或直接 `routeData.handler` 懒加载；视图为 TSX（RSS/Atom/JSON）。
- **构建**：`build:routes` 生成 `assets/build/routes.js`、radar、maintainers、route-paths 类型；tsdown 多配置产出 dist、worker、vercel、container 等。

### 3.3 二者对比摘要

| 维度       | rss                              | RSSHub                             |
|------------|----------------------------------|------------------------------------|
| 语言/模块  | JS + CommonJS                   | TS + ESM                           |
| 框架       | Koa                             | Hono                               |
| 路由注册   | router.js 手写 + v2 扫描挂载     | registry + namespaces 动态注册     |
| 视图       | .art 模板                        | TSX                                |
| 配置       | config.js + env                 | config.ts + 类型化 env             |
| 构建       | 无 TS 构建，仅脚本生成 radar/maintainer | build-routes + tsdown 多目标 |
| 部署       | Node 直接运行 / Vercel 入口      | Node / Vercel / Worker / Container |

---

## 4. 使用方法

### 4.1 rss

- **安装**：在 `rss/` 下执行 `npm install`（或 pnpm，以 lockfile 为准）。
- **开发**：`npm run dev`（nodemon 监听 lib、.env 等）。
- **启动**：`npm start`（`node lib/index.js`），默认端口 1200（或 `PORT`）。
- **环境变量**：见 `lib/config.js`（PORT、CACHE_TYPE、REDIS_URL、PROXY_URI、HTTP_BASIC_AUTH_*、各站 COOKIE 等）；文档见 `docs/install/README.md`。
- **部署**：Docker/Compose 见 scripts/ansible 与文档；Vercel 通过 `vercel.json` 指向 `/api/vercel.js`。

### 4.2 RSSHub

- **安装**：在 `RSSHub/` 下执行 `pnpm install`（需 Node ^22.20.0||^24）。
- **构建路由**：`pnpm run build:routes`（生成 `assets/build/`）。
- **开发**：`pnpm run dev`（tsx watch lib/index.ts）。
- **启动**：先 `pnpm run build`（或对应 tsdown 目标），再 `pnpm start`（`node dist/index.mjs` 等）。
- **环境变量**：见 `lib/config.ts` 的 ConfigEnvKeys；部署文档见官方 docs。
- **部署**：Vercel（vercel-build）、Worker（worker-build + wrangler）、Container（container-build + wrangler）等。

---

## 5. 自建 rss 与官方 RSSHub 的差异与可迁移点

- **架构**：rss 为 Koa + 手写 router + v2 按目录扫描；RSSHub 为 Hono + registry 中心化注册 + namespace/route 元数据。迁移时需将 `lib/v2/<站点>/router.js` 的“路由 path + handler”抽象为 RSSHub 的 `route.path` + `route.handler`，并补全 `namespace.ts`（name、url、description 等）。
- **类型与视图**：rss 使用 .art 模板与 ctx.body；RSSHub 使用 TSX 与统一 Data/DataItem 类型。迁移需把每条路由的返回格式对齐到 `Data`，并改用 views 的 TSX 渲染。
- **配置**：rss 的 `config.js` 与 RSSHub 的 `config.ts` 环境变量大部分对应（PORT、缓存、代理、认证等），可逐项对照并补全类型与默认值。
- **构建与部署**：rss 无构建步骤，直接运行；RSSHub 依赖 `build:routes` 与 tsdown。若要从 rss 迁到 RSSHub 代码库，需引入 pnpm、Node 版本升级、以及 Vercel/Worker/Container 的构建与部署配置。

以上为两项目的结构、层级、依赖与使用方法的分析结果。
