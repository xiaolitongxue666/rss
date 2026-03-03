# rss 栈部署到 moicen 服务器（计划摘要）

## 约定

- **打包相关脚本**均在 rss 项目内：`scripts/stack-images-pack.sh`、`scripts/stack-upload-to-server.sh`、`scripts/stack-images-load.sh`。
- **打包产物**放在 rss 项目根目录：`rss-stack-images.tar`（及可选 `rss-stack-images.tar.size`），已加入 `.gitignore`，不提交。

## 本地

1. **打包**（输出到 rss 根目录）：`./scripts/stack-images-pack.sh`
2. **一键打包并上传到服务器**：`./scripts/stack-upload-to-server.sh`  
   - 会先打包（除非 `SKIP_PACK=1`），再 scp 到 `REMOTE_USER@REMOTE_HOST`，最后 ssh 执行 mv + `docker load`。  
   - 默认 `REMOTE_USER=leonli`、`REMOTE_HOST=moicen.com`、`REMOTE_ALCHEMY_DIR=/home/alchemy/RSS`。

## 服务器

1. **登录**：`ssh moicen-vnc` → `sudo su - alchemy` → `cd /home/alchemy/RSS/rss`
2. **Docker 权限**：确认当前用户（如 alchemy）有 Docker 权限，执行 `docker ps` 无 permission denied。若无，需由管理员执行 `sudo usermod -aG docker alchemy` 后重新登录。
3. **拉代码**：`git pull`、`git submodule update --init --recursive`
4. **加载镜像**（在上传的 tar 引入到 Docker 后再启动）：  
   若 tar 在 `/home/alchemy/RSS/rss-stack-images.tar`：  
   `STACK_IMAGES_TAR=/home/alchemy/RSS/rss-stack-images.tar ./scripts/stack-images-load.sh`  
   若在 `/tmp`：`./scripts/stack-images-load.sh`（默认读 `/tmp/rss-stack-images.tar`）。
5. **停止旧容器**：服务器上可能有老版本栈在运行，先停止再起新服务：  
   `./scripts/stack-down.sh` 或 `./scripts/stack-stop-all.sh`
6. **一键启动**：`./scripts/stack-build-and-up.sh`  
   首次部署需先配置 `.env`：`cp .env.stack.example .env` 并填写 `RAW_SUB_URL` 等。

**合并 2～6 步**：拉代码后可只执行 `./scripts/stack-server-update-and-start.sh`，脚本会依次：检查 Docker 权限 → 加载镜像（若存在 tar）→ 停止旧容器 → 启动栈。

## 验证

访问 https://ai.moicen.com/rss/

详细步骤见 [DEPLOYMENT-STACK.md](../DEPLOYMENT-STACK.md) 第六节。
