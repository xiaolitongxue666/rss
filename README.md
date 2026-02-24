<p align="center">
<img src="https://docs.rsshub.app/logo.png" alt="RSSHub" width="100">
</p>
<h1 align="center">RSSHub</h1>

> 🍰 Everything is RSSible

[![telegram](https://img.shields.io/badge/chat-telegram-brightgreen.svg?logo=telegram&style=flat-square)](https://t.me/rsshub)
[![npm publish](https://img.shields.io/github/actions/workflow/status/DIYgod/RSSHub/npm-publish.yml?branch=master&label=npm%20publish&logo=npm&style=flat-square)](https://www.npmjs.com/package/rsshub)
[![docker publish](https://img.shields.io/github/actions/workflow/status/DIYgod/RSSHub/docker-release.yml?branch=master&label=docker%20publish&logo=docker&style=flat-square)](https://hub.docker.com/r/diygod/rsshub)
[![test](https://img.shields.io/github/actions/workflow/status/DIYgod/RSSHub/test.yml?branch=master&label=test&logo=github&style=flat-square)](https://github.com/DIYgod/RSSHub/actions/workflows/test.yml?query=event%3Apush+branch%3Amaster)
[![Test coverage](https://img.shields.io/codecov/c/github/DIYgod/RSSHub.svg?style=flat-square&logo=codecov)](https://app.codecov.io/gh/DIYgod/RSSHub/branch/master)
[![CodeFactor](https://www.codefactor.io/repository/github/diygod/rsshub/badge)](https://www.codefactor.io/repository/github/diygod/rsshub)
[![DeepScan grade](https://deepscan.io/api/teams/6244/projects/8135/branches/92448/badge/grade.svg)](https://deepscan.io/dashboard#view=project&tid=6244&pid=8135&bid=92448)

## Introduction

RSSHub is an open source, easy to use, and extensible RSS feed generator. It's capable of generating RSS feeds from pretty much everything.

RSSHub delivers millions of contents aggregated from all kinds of sources, our vibrant open source community is ensuring the deliver of RSSHub's new routes, new features and bug fixes.

RSSHub can be used with browser extension [RSSHub Radar](https://github.com/DIYgod/RSSHub-Radar) and mobile auxiliary app [RSSBud](https://github.com/Cay-Zhang/RSSBud) (iOS) and [RSSAid](https://github.com/LeetaoGoooo/RSSAid) (Android)

[English docs](https://docs.rsshub.app/en) | [Telegram Group](https://t.me/rsshub) | [Telegram Channel](https://t.me/awesomeRSSHub)

---

RSSHub 是一个开源、简单易用、易于扩展的 RSS 生成器，可以给任何奇奇怪怪的内容生成 RSS 订阅源。RSSHub 借助于开源社区的力量快速发展中，目前已适配数百家网站的上千项内容

可以配合浏览器扩展 [RSSHub Radar](https://github.com/DIYgod/RSSHub-Radar) 和 移动端辅助 App [RSSBud](https://github.com/Cay-Zhang/RSSBud) (iOS) 与 [RSSAid](https://github.com/LeetaoGoooo/RSSAid) (Android) 食用

[中文文档](https://docs.rsshub.app) | [Telegram 群](https://t.me/rsshub) | [Telegram 频道](https://t.me/awesomeRSSHub)

## Special Thanks

### Contributors

[![](https://opencollective.com/RSSHub/contributors.svg?width=890)](https://github.com/DIYgod/RSSHub/graphs/contributors)

Logo designer [sheldonrrr](https://dribbble.com/sheldonrrr)

### Backers

<a href="https://www.cloudflare.com" target="_blank"><img height="50px" src="https://i.imgur.com/7Ph27Fq.png"></a>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://www.netlify.com" target="_blank"><img height="40px" src="https://i.imgur.com/cU01915.png"></a>

## Related Projects

-   [RSSHub Radar](https://github.com/DIYgod/RSSHub-Radar) | 一个可以帮助你快速发现和订阅当前网站 RSS 和 RSSHub 的浏览器扩展
-   [RSSBud](https://github.com/Cay-Zhang/RSSBud) ([TestFlight 公测](https://testflight.apple.com/join/rjCVzzHP)) | iOS 平台的 RSSHub Radar，专为移动生态优化
-   [RSSAid](https://github.com/LeetaoGoooo/RSSAid)  | 基于 Flutter 构建的 Android 平台的 RSSHub Radar
-   [DocSearch](https://github.com/Fatpandac/DocSearch) | Link RSSHub DocSearch into Raycast

## Join Us

We welcome all pull requests. Suggestions and feedback are also welcomed [here](https://github.com/DIYgod/RSSHub/issues).

Refer to [Join Us](https://docs.rsshub.app/en/joinus/quick-start.html)

见 [参与我们](https://docs.rsshub.app/joinus/quick-start.html)

## Deployment

Refer to [Deployment](https://docs.rsshub.app/en/install/)

见 [部署](https://docs.rsshub.app/install/)

### RSS + Clash 栈（本仓库）

将 RSSHub 与 Clash、Redis、Subconverter 统一编排（国外走代理、国内直连，可选 Cookie）。clash-aio 以 **git submodule** 形式位于 `./clash-aio`。**构建与使用**见 [DEPLOYMENT-STACK.md](DEPLOYMENT-STACK.md)：克隆时 `--recurse-submodules` 或 `git submodule update --init`、`.env` 准备、可选 `./scripts/stack-pre-install.sh`、一键 `./scripts/stack-build-and-up.sh`、以及通过 URL 在阅读器中订阅 RSS。**从零验证**：删除 `.env` 后先执行 `./scripts/stack-pre-install.sh` 再执行 `./scripts/stack-build-and-up.sh` 可验证全流程（需在生成的 `.env` 中补填 `RAW_SUB_URL`）。

## Support RSSHub

Refer to [Support RSSHub](https://docs.rsshub.app/en/support/)

见 [支持 RSSHub](https://docs.rsshub.app/support/)

RSSHub is open source and completely free under the MIT license. However, just like any other open source project, as the project grows, the hosting, development and maintenance requires funding support.

You can support RSSHub via donations.

### Recurring Donation

Recurring donors will be rewarded via express issue response, or even have your name displayed on our GitHub page and website.

-   Become a Sponser on [GitHub](https://github.com/sponsors/DIYgod)
-   Become a Sponser on [Open Collective](https://opencollective.com/RSSHub)
-   Become a Sponser on [Patreon](https://www.patreon.com/DIYgod)
-   Become a Sponser on [爱发电](https://afdian.net/@diygod)
-   Contact us directly: i@diygod.me

### One-time Donation

We accept donations via the following ways:

-   [WeChat Pay](https://archive.diygod.me/images/wx.jpg)
-   [Alipay](https://archive.diygod.me/images/zfb.jpg)
-   [Paypal](https://www.paypal.me/DIYgod)

## Author

**RSSHub** © [DIYgod](https://github.com/DIYgod), Released under the [MIT](./LICENSE) License.<br>
Authored and maintained by DIYgod with help from contributors ([list](https://github.com/DIYgod/RSSHub/contributors)).

> Blog [@DIYgod](https://diygod.me) · GitHub [@DIYgod](https://github.com/DIYgod) · Twitter [@DIYgod](https://twitter.com/DIYgod) · Telegram Channel [@awesomeDIYgod](https://t.me/awesomeDIYgod)
