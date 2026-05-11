# 灾难恢复 Runbook

## 恢复来源

仓库不再管理自动异地备份。灾难恢复从以下人工控制的输入开始：

- 生产服务器 `/opt/lihan_ai_deploy/shared/backups/postgres/` 下仍存在的 dump。
- 你手动下载到本地机器的 dump。
- 你在仓库之外自行管理的可信存储里的 dump。

`.env.production`、CPA config/auth 文件和 Cloudflare Tunnel 凭据必须保存在 git 之外。只有数据库 dump 不足以完整恢复生产。

## 灾难前准备

在 origin 服务器上：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-cron.sh
ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<dump>.dump
```

在本地机器定期下载重要 dump：

```bash
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump .
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump.sha256 .
```

还要私下保存：

- `/opt/lihan_ai_deploy/shared/.env.production`
- 如果启用 CPA，保存 `/opt/lihan_ai_deploy/shared/data/cpa/`
- 如果启用 Cloudflare Tunnel，保存 `/opt/lihan_ai_deploy/shared/cloudflared/`

## 新服务器恢复

1. 准备一台有 Docker 和 SSH 访问的 Linux 服务器。
2. 在本地 clone 或 fetch 本仓库。
3. 初始化 release 目录：

```bash
DEPLOY_HOST=<deploy-user>@<new-origin-host> bash ops/deploy-release.sh bootstrap
```

4. 把运行时文件复制到新服务器：

```bash
scp .env.production <deploy-user>@<new-origin-host>:/opt/lihan_ai_deploy/shared/.env.production
scp <dump>.dump <deploy-user>@<new-origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/
scp <dump>.dump.sha256 <deploy-user>@<new-origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/
```

5. 准备并 smoke release：

```bash
DEPLOY_HOST=<deploy-user>@<new-origin-host> DEPLOY_REF=main bash ops/deploy-release.sh prepare
DEPLOY_HOST=<deploy-user>@<new-origin-host> SMOKE_BACKUP_PATH=/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump bash ops/deploy-release.sh smoke
DEPLOY_HOST=<deploy-user>@<new-origin-host> bash ops/deploy-release.sh promote
```

6. 在新服务器恢复选定 dump：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/restore-postgres.sh /opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

7. 验证 New API 登录、`/api/status`、用测试 token 跑 `/v1/models`、可选 CPA 渠道路由和可选 Cloudflare Tunnel。

## 最终切换

只有满足以下条件后，才切 DNS 或 tunnel 路由：

- `ops/check-production-runtime.sh` 通过。
- `ops/drill-restore-stack.sh` 针对选定 dump 通过。
- New API 后台登录正常。
- 重要用户、token 和渠道存在。
- CPA 配置路径是文件，不是目录。

恢复期间不要运行 `docker compose down -v`，它会删除 named volume 数据。
