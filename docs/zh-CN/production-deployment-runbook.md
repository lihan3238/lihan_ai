# 生产部署 Runbook

## 首次 Origin 初始化

使用一台 Linux origin 服务器运行 New API、PostgreSQL、Redis、Caddy 和 Uptime Kuma。

生产环境从 `main` 部署。部署 wrapper 会拒绝非 `main` 的生产部署，除非为了已记录的紧急情况显式设置 `ALLOW_NON_MAIN_PROD_DEPLOY=1`。

Caddy 不是 New API 自带组件。它是本仓库里的反向代理容器：负责公网 `80/443`、自动申请 HTTPS 证书，并把应用流量转发到 Docker 内部的 `new-api:3000`。

1. 将本仓库 clone 到 `/opt/lihan_ai`。
2. 复制 `.env.production.example` 为 `.env.production`。
3. 替换所有 `CHANGE_ME`，并设置 `DOMAIN` 和 `ACME_EMAIL`。
4. `.env.production` 只保留在服务器上；它被 git 忽略。
5. `SESSION_SECRET`、`POSTGRES_PASSWORD` 和 `REDIS_PASSWORD` 使用 URL-safe 随机值。优先用 `openssl rand -hex 32`。除非后续把 DSN 构造改成 URL-encode，否则 PostgreSQL 和 Redis 密码不要使用包含 `/`、`+` 或 `=` 的 base64 值。
6. 运行：

```bash
bash ops/bootstrap-server.sh
ENV_FILE=.env.production bash ops/preflight.sh
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

后续生产更新优先使用 `docs/zh-CN/release-deployment-runbook.md` 里的 release 部署流程。上面的 `/opt/lihan_ai` 直接 checkout 流程仍可用于首次 bootstrap 和 legacy 回退，但稳定后生产应从 `/opt/lihan_ai_deploy/current` 运行，运行时文件放在 `/opt/lihan_ai_deploy/shared`。

第一次通过浏览器打开 New API 时，看到上游初始化页面并要求创建 root/admin 是正常现象。`SESSION_SECRET`、`POSTGRES_PASSWORD` 和 `REDIS_PASSWORD` 是应用、数据库和运行时 secret，不会自动创建 New API 管理员账号。

## 防火墙基线

origin 服务器建议：

- SSH 只允许你自己的可信 IP 访问；如果 provider firewall 暂时无法按 IP 限制，bootstrap 后至少使用 SSH key 登录并关闭密码登录。
- 公网开放 TCP `80` 和 `443`，用于 Caddy 和 ACME 证书签发。
- 不要把 PostgreSQL `5432`、Redis `6379`、New API `3000`、Uptime Kuma `3001` 或 CPA `8317` 暴露到公网。
- provider firewall 和主机 firewall 保持一致。Caddy 健康但公网 HTTPS 失败时，按 DNS、provider firewall、主机 firewall、Caddy 日志的顺序排查。

服务器上快速查看监听端口：

```bash
sudo ss -lntp | grep -E ':80|:443|:8317|:5432|:6379'
```

基础生产栈只有 `80` 和 `443` 应该被公网访问到。CPA `8317` 只有在临时启用 UI override 时，才应该出现在 `127.0.0.1` 上。

## 从本地远程部署

推荐的 release 部署：

```bash
DEPLOY_HOST=root@x.x.x.x bash ops/deploy-release.sh prepare
DEPLOY_HOST=root@x.x.x.x RELEASE_ID=<release-id> bash ops/deploy-release.sh smoke
DEPLOY_HOST=root@x.x.x.x RELEASE_ID=<release-id> bash ops/deploy-release.sh promote
```

legacy 简化部署仍可通过 SSH 部署一个干净的 Git ref：

```bash
DEPLOY_HOST=root@x.x.x.x DEPLOY_PATH=/opt/lihan_ai DEPLOY_REF=main bash ops/deploy-prod.sh
```

两条路径都默认拒绝非 `main` 的生产 ref。legacy 部署脚本还会在远程仓库存在本地未提交改动时拒绝继续。release 部署路径在存在当前生产 stack 时，会在替换容器前先创建 PostgreSQL 备份。

## 验证

运行：

```bash
DEPLOY_HOST=root@x.x.x.x bash ops/verify-remote-prod.sh
```

如果需要真实计费探针，先在 New API 创建一个低额度命名测试 token，然后运行：

```bash
DEPLOY_HOST=root@x.x.x.x RUN_LIVE_E2E=1 NEW_API_TEST_TOKEN_NAME=test_token_name NEW_API_TEST_MODEL=glm-5.1 bash ops/verify-remote-prod.sh
```

## 排障

`docker compose logs -f new-api` 会持续跟随日志。看到任务进度轮询、渠道同步、数据看板刷新和 `GET /api/status` 是 New API 正常运行时日志。按 `Ctrl-C` 只是停止跟随日志，不会停止容器。

如果 `new-api` 因 PostgreSQL URL parse error 变成 unhealthy，先检查 `POSTGRES_PASSWORD`。当前 URL-style DSN 遇到 `/`、`+`、`=`、`@` 或 `:` 这类字符会解析失败。用 `openssl rand -hex 32` 生成新的 URL-safe 值，更新 `.env.production` 后重建 stack。

如果 `curl -i http://127.0.0.1/api/status` 访问 `80` 失败，说明 Caddy 没有监听宿主机 `80`，或你 curl 的层级不对。New API 在 Docker 内部监听 `3000`；生产宿主机访问通常应经过 Caddy：

```bash
docker exec relay-new-api wget -q -O - http://localhost:3000/api/status
curl -i https://$DOMAIN/api/status
```

如果 Caddy 报 `:443` 的 `address already in use`，查出占用端口的进程：

```bash
sudo ss -lntp | grep -E ':80|:443'
```

停止或调整冲突的 Web 服务后，再重启 Compose stack。

如果 Caddy 日志里出现通过 `127.0.0.53` 查询失败、ACME 失败等错误，先修复宿主机 DNS。Caddy 需要出站 DNS 和 HTTPS 访问 Let's Encrypt 或 ZeroSSL，同时公网入站 `80/443` 必须能到达 origin。

如果生产站点里 New API 仍显示 `localhost:3000`，到 New API 后台把 public site/base URL 改成 `https://$DOMAIN`。Caddy 只负责反代流量，不会自动改应用自身的公开 URL 设置。

GitHub、LinuxDo 等外部登录方式需要先在对应 provider 创建 OAuth app，把 callback URL 指向生产域名，并在 New API 后台填写对应配置。只在 HTTPS 正常、管理员账号已加固之后启用。

## 回滚

使用 release 部署时，回滚到上一条 release：

```bash
DEPLOY_HOST=root@x.x.x.x bash ops/deploy-release.sh rollback
```

使用 legacy 简化部署时，重新部署一个已知可用的 Git ref：

```bash
DEPLOY_HOST=root@x.x.x.x DEPLOY_REF=<known-good-ref> bash ops/deploy-prod.sh
```

如果数据已经发生变化，先导出当前数据库用于审计，再恢复已知可用的 PostgreSQL dump。
