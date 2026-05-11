# 生产部署 Runbook

## 首次 Origin 初始化

使用一台 Linux origin 服务器运行 New API、PostgreSQL、Redis 和 Caddy。如果启用 Cloudflare Tunnel，`cloudflared` 成为公网入口，Caddy 会缩容为 0。

生产环境从 `main` 部署。部署 wrapper 默认拒绝非 `main` 的生产部署，除非为了已记录的紧急情况显式设置 `ALLOW_NON_MAIN_PROD_DEPLOY=1`。

如果使用 `api.lihan3238.com` 和 `origin.lihan3238.top` 这条 Cloudflare for SaaS custom-hostname 路径，先让基础 origin stack 健康，再按 `docs/zh-CN/cloudflare-saas-runbook.md` 操作。

1. 初始 bootstrap 可把本仓库 clone 到 `/opt/lihan_ai`，或直接使用 `docs/zh-CN/release-deployment-runbook.md` 的 release 目录模型。
2. 复制 `.env.production.example` 为 `.env.production`。
3. 替换所有 `CHANGE_ME`，并设置 `DOMAIN` 和 `ACME_EMAIL`。
4. `.env.production` 只保留在服务器上；它被 git 忽略。
5. `SESSION_SECRET`、`POSTGRES_PASSWORD` 和 `REDIS_PASSWORD` 使用 URL-safe 随机值，优先用 `openssl rand -hex 32`。
6. 运行：

```bash
bash ops/bootstrap-server.sh
ENV_FILE=.env.production bash ops/preflight.sh
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

后续生产更新优先使用 `docs/zh-CN/release-deployment-runbook.md` 的 release 流程：生产从 `/opt/lihan_ai_deploy/current` 运行，运行时文件放在 `/opt/lihan_ai_deploy/shared`。

第一次通过浏览器打开 New API 时，看到上游初始化页面并要求创建 root/admin 是正常现象。

## 防火墙基线

- SSH 尽量只允许可信 IP 访问。
- 直连源站模式下，公网开放 TCP `80` 和 `443` 给 Caddy 和证书签发。
- Cloudflare Tunnel 模式下，源站不要公开 TCP `80` 或 `443`；只允许 `cloudflared` 出站连接。
- 不要把 PostgreSQL `5432`、Redis `6379`、New API `3000` 或 CPA `8317` 暴露到公网。
- provider firewall 和主机 firewall 保持一致。

快速查看监听：

```bash
sudo ss -lntp | grep -E ':80|:443|:8317|:5432|:6379'
```

直连源站模式下，只有 `80` 和 `443` 应该被公网访问。Tunnel 模式下，源站不需要公开这两个端口。CPA `8317` 只有临时启用 UI override 时才应出现在 `127.0.0.1`。

## 从本地远程部署

推荐 release 部署：

```bash
DEPLOY_HOST=root@x.x.x.x bash ops/deploy-release.sh prepare
DEPLOY_HOST=root@x.x.x.x bash ops/deploy-release.sh smoke
DEPLOY_HOST=root@x.x.x.x bash ops/deploy-release.sh promote
```

`prepare` 会记录远端 `candidate`，所以正常 `smoke` 和 `promote` 不需要 `RELEASE_ID`。

Legacy 直接 checkout 部署：

```bash
DEPLOY_HOST=root@x.x.x.x DEPLOY_PATH=/opt/lihan_ai DEPLOY_REF=main bash ops/deploy-prod.sh
```

## 验证

```bash
DEPLOY_HOST=root@x.x.x.x bash ops/verify-remote-prod.sh
```

服务器上：

```bash
cd /opt/lihan_ai_deploy/current
COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh
ENV_FILE=.env.production bash ops/backup-cron.sh
curl -i https://api.lihan3238.com/api/status
```

真实计费探针需要先在 New API 创建低额度测试 token：

```bash
DEPLOY_HOST=root@x.x.x.x RUN_LIVE_E2E=1 NEW_API_TEST_TOKEN_NAME=test_token_name NEW_API_TEST_MODEL=glm-5.1 bash ops/verify-remote-prod.sh
```

## 排障

`docker compose logs -f new-api` 会持续跟随日志。按 `Ctrl-C` 只是停止看日志，不会停止容器。

如果 `new-api` 因 PostgreSQL URL parse error 不健康，先检查 `POSTGRES_PASSWORD`。URL 风格 DSN 遇到 `/`、`+`、`=`、`@` 或 `:` 等字符会出问题。

直连源站 HTTPS 失败时，依次检查 DNS、provider firewall、主机 firewall、Caddy 日志和 New API 日志。Tunnel 模式失败时，先看 `relay-cloudflared` 日志和 Cloudflare tunnel 配置文件。
