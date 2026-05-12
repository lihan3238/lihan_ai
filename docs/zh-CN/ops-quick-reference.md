# 运维速查

## 每日快速检查

```bash
cd /opt/lihan_ai_deploy/current
readlink -f /opt/lihan_ai_deploy/current
docker compose -p lihan_ai --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml ps
COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh
curl -i https://api.lihan3238.com/api/status
```

启用 CPA 或 Cloudflare Tunnel 时，追加 `-f docker-compose.cpa.yml` 和 `-f docker-compose.cloudflare-tunnel.yml`。

## Release 部署

```bash
git fetch origin
git switch main
git pull --ff-only origin main

DEPLOY_HOST=<deploy-user>@<origin-host> DEPLOY_REF=main bash ops/deploy-release.sh prepare
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh smoke
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh promote
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh status
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/verify-remote-prod.sh
```

`prepare` 会用 `ops/sync-env-template.sh` 补齐生产 env 缺失键，创建备份，并记录远端 `candidate`。除非明确测试旧候选版本，否则不要填 `RELEASE_ID`。

如果 promote 过程中 SSH 断开，先检查状态，再按需恢复：

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh status
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh recover
```

## 备份

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-cron.sh
tail -n 120 logs/backup-cron.log
ENV_FILE=.env.production bash ops/prune-runtime-storage.sh all
```

默认本地保留上限：`BACKUP_KEEP=30`、`BACKUP_MAX_TOTAL_MB=2048`、`BACKUP_CRON_LOG_MAX_MB=10`、`BACKUP_CRON_LOG_KEEP=5`、`CONFIG_SNAPSHOT_KEEP=30`、`CONFIG_SNAPSHOT_MAX_TOTAL_MB=256`。

Crontab：

```cron
15 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/backup-cron.sh
```

手动 dump 和校验：

```bash
backup="$(ENV_FILE=.env.production bash ops/backup-postgres.sh)"
echo "$backup"
ENV_FILE=.env.production bash ops/verify-postgres-backup.sh "$backup"
```

## 手动下载

在本地机器执行：

```bash
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump .
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump.sha256 .
```

## 恢复演练

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/drill-restore-postgres.sh backups/postgres/<dump>.dump
ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<dump>.dump
```

## 恢复

只在维护窗口执行：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-postgres.sh
ENV_FILE=.env.production bash ops/restore-postgres.sh backups/postgres/<dump>.dump
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

## CPA UI

服务器上：

```bash
cd /opt/lihan_ai_deploy/current
ops/cpa-ui.sh open
ops/cpa-ui.sh ps
```

本地机器：

```bash
ssh -L 8317:127.0.0.1:8317 <deploy-user>@<origin-host>
```

用完关闭：

```bash
ops/cpa-ui.sh close
```

## Env 对齐

```bash
cd /opt/lihan_ai_deploy/current
bash ops/sync-env-template.sh /opt/lihan_ai_deploy/shared/.env.production .env.production.example
ENV_FILE=.env.production bash ops/preflight.sh
```

同步只追加缺失键，不覆盖 secret，也不删除废弃键。

## New API 分组

只保留 `default` 和 `vip`。旧 `standard` 用户、token、渠道能力和价格要在 New API 后台手动迁到 `default`。

```bash
bash ops/validate-ops-profile.sh config/ops-profiles/glm-default.example.json
bash ops/channel-health-advisor.sh config/ops-profiles/glm-default-health.example.json
```

## Small Circle Launch

修改套餐文案或订阅计划前，先看 `docs/zh-CN/new-api-small-circle-launch-runbook.md`。开始售卖前验证后台手动开通按钮：

```bash
NEW_API_BASE_URL=https://api.lihan3238.com \
NEW_API_ADMIN_USERNAME=<admin> \
NEW_API_ADMIN_PASSWORD=<password> \
bash ops/check-new-api-admin-frontend.sh
```

New API `v1.0.0-rc.5` 已包含后台 dropdown 修复。本机 E2E 通过后，生产保持
`calciumion/new-api:latest` 和 `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=0`。
如果官方 latest 未通过后台 E2E，才把 `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1` 作为临时
rollback 路径，并配合 `DEPLOY_LOCAL_NEW_API_BUILD_MODE=pull` 和非官方 `LOCAL_NEW_API_IMAGE`；
runtime check 会拒绝 patched-mode 下实际容器仍为 `calciumion/new-api:latest` 的发布。

## 主机压力检查

```bash
df -h
df -Pi
docker system df
docker ps -a
```

不要删除 `/opt/containerd`。除非明确要删除状态，否则不要运行 `docker compose down -v`。
