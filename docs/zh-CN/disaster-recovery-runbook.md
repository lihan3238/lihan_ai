# 灾难恢复 Runbook

## 需要保护的数据

保护以下内容：

- `backups/postgres/` 下的 PostgreSQL dumps。
- `.env.production`。
- `snapshots/config/` 下的脱敏和私有配置快照。
- `RESTIC_PASSWORD`，它必须保存在生产服务器之外。

Redis 是运行时状态，不是主要恢复来源。

## 离线备份

配置 restic：

```bash
export RESTIC_REPOSITORY=sftp:user@backup-host:/srv/restic/lihan-ai
export RESTIC_PASSWORD='<store outside the server>'
export CONFIG_SNAPSHOT_GPG_RECIPIENT='<optional-gpg-recipient>'
ENV_FILE=.env.production bash ops/offsite-backup.sh
```

在 origin 上使用 cron：

```cron
15 3 * * * cd /opt/lihan_ai && ENV_FILE=.env.production bash ops/production-monitor.sh backup
35 3 * * * cd /opt/lihan_ai && ENV_FILE=.env.production bash ops/production-monitor.sh offsite
*/15 * * * * cd /opt/lihan_ai && ENV_FILE=.env.production bash ops/production-monitor.sh audit
```

使用 release 部署时，改用：

```cron
15 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh backup
35 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh offsite
*/15 * * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh audit
```

`ops/production-monitor.sh` 会把 backup/offsite 的最新状态写入 `logs/production-monitor-*.status`。`audit` 还会生成 `logs/ops-health/status.json` 和 `logs/ops-health/index.html`，灾备前可以直接看到最新 dump、restic snapshot 可见性、磁盘压力和恢复演练年龄。

## 恢复到新服务器

1. 准备一台新服务器，并安装 Docker 与 Compose plugin。
2. 紧急 legacy 恢复可将仓库 clone 到 `/opt/lihan_ai`；release 恢复则先运行 `ops/deploy-release.sh bootstrap` 重建 `/opt/lihan_ai_deploy`。
3. release 部署把 `.env.production` 恢复到 `/opt/lihan_ai_deploy/shared/.env.production`；legacy 恢复则放到 `/opt/lihan_ai/.env.production`。
4. 从 restic 恢复最新 dump。
5. 启动 PostgreSQL 和 Redis。
6. 在当前部署目录运行 `ENV_FILE=.env.production bash ops/restore-postgres.sh <backup.dump>`。
7. 启动完整生产栈。
8. stack 启动后运行 `ENV_FILE=.env.production bash ops/check-production-runtime.sh`。
9. 运行 `DEPLOY_HOST=<new-server> bash ops/verify-remote-prod.sh`。

## 演练周期

每月和重大 New API 升级前执行一次隔离恢复演练：

```bash
ENV_FILE=.env.production bash ops/backup-postgres.sh
bash ops/drill-restore-postgres.sh backups/postgres/<backup>.dump
ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<backup>.dump
```

建议把完整 stack 恢复演练纳入月度 cron：

```cron
20 4 1 * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh restore-drill
```

如果已经在 Uptime Kuma 中创建 Restore Drill Push monitor，把 `MONITOR_PUSH_RESTORE_DRILL_URL` 放进 `.env.production`。Ops Health 默认在恢复演练超过 35 天未更新时给出 WARN。

恢复后运行：

```bash
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```
