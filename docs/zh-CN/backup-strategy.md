# 备份策略

## 范围

当前生产备份模型刻意保持很小：

- 创建 PostgreSQL custom-format dump。
- 每个 dump 创建后立即校验。
- dump 保存在生产服务器的 shared 部署目录。
- 需要外部副本时，用 `scp` 手动下载。
- 恢复和迁移演练保持人工显式执行。

仓库不再包含远端自动备份、webhook 告警、状态看板或监控服务。

## 备份位置

Release 部署运行目录：

```text
/opt/lihan_ai_deploy/current
```

运行时状态目录：

```text
/opt/lihan_ai_deploy/shared
```

PostgreSQL dump 默认写入：

```text
/opt/lihan_ai_deploy/shared/backups/postgres/
```

不要提交 `.env.production`、`backups/`、`snapshots/`、CPA 运行时文件或下载出来的 dump。

## 手动备份

在生产服务器上：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-postgres.sh
```

命令会打印创建的 dump 路径。继续校验：

```bash
ENV_FILE=.env.production bash ops/verify-postgres-backup.sh backups/postgres/<dump>.dump
```

## 本地备份 Cron

定时备份使用 `ops/backup-cron.sh`。它会创建 dump、立即校验，并把普通文本日志追加到 `BACKUP_CRON_LOG_DIR`：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-cron.sh
```

建议 crontab：

```cron
15 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/backup-cron.sh
```

仓库不会自动安装 cron；请在 origin 服务器上确认后手动添加。

## 手动下载

在本地机器上：

```bash
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump .
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump.sha256 .
```

下载后校验：

```bash
sha256sum -c <dump>.dump.sha256
```

如果 `.sha256` 文件里是服务器绝对路径，改用：

```bash
sha256sum <dump>.dump
```

然后人工比对 digest。

## 恢复演练

只验证 PostgreSQL：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/drill-restore-postgres.sh backups/postgres/<dump>.dump
```

完整 stack 演练：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<dump>.dump
```

重大部署、服务器迁移或清理旧运行时目录前，先跑一次完整 stack 演练。

## 恢复

恢复会替换目标数据库。先停止应用写入，并在恢复前再创建一个新备份：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-postgres.sh
ENV_FILE=.env.production bash ops/restore-postgres.sh backups/postgres/<dump>.dump
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

备份或恢复时不要运行 `docker compose down -v`。PostgreSQL 和 Redis 状态在 Docker named volumes 里。

## 保留策略

`BACKUP_RETENTION_DAYS` 控制 `ops/backup-postgres.sh` 的本地 dump 保留时间。保留足够近期 dump 支撑回滚和迁移；删除服务器副本前，先把重要 dump 手动下载到本地。

`ops/prune-runtime-storage.sh` 统一执行运行时存储清理。`ops/backup-postgres.sh`、`ops/backup-cron.sh` 和 `ops/export-config-snapshot.sh` 会自动调用它，也可以手动运行：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/prune-runtime-storage.sh all
```

默认上限：

```env
BACKUP_RETENTION_DAYS=14
BACKUP_KEEP=30
BACKUP_MAX_TOTAL_MB=2048
BACKUP_CRON_LOG_MAX_MB=10
BACKUP_CRON_LOG_KEEP=5
CONFIG_SNAPSHOT_KEEP=30
CONFIG_SNAPSHOT_MAX_TOTAL_MB=256
```

dump 清理会先删除最旧的 `.dump`，并同步删除对应的 `.dump.sha256`。Backup cron log 超过 `BACKUP_CRON_LOG_MAX_MB` 时会轮转，并只保留 `BACKUP_CRON_LOG_KEEP` 份旧 log。Config snapshot 按 `CONFIG_SNAPSHOT_KEEP` 和 `CONFIG_SNAPSHOT_MAX_TOTAL_MB` 保留。
