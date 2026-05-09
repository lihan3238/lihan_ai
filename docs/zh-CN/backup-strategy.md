# 备份策略

## 当前机制

项目将 New API 状态存储在 PostgreSQL 中。主要备份命令是：

```bash
ENV_FILE=.env.production bash ops/backup-postgres.sh
```

脚本会在 `backups/postgres/` 下创建 PostgreSQL custom-format dump，使用 `pg_restore` 验证 dump 可读，并在存在 `sha256sum` 时写入 `.sha256` 校验文件。备份目录被 git 忽略。生产环境命令应传入 `ENV_FILE=.env.production`，确保 Compose 使用和运行中服务一致的变量。

不恢复、只校验备份：

```bash
ENV_FILE=.env.production bash ops/verify-postgres-backup.sh backups/postgres/<backup>.dump
```

恢复操作刻意保持显式且具破坏性：

```bash
ENV_FILE=.env.production bash ops/restore-postgres.sh backups/postgres/<backup>.dump
```

不触碰当前数据库的隔离恢复演练：

```bash
bash ops/drill-restore-postgres.sh backups/postgres/<backup>.dump
```

需要更接近真实灾备时，运行完整隔离栈演练：

```bash
ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<backup>.dump
```

它会在独立 Docker 网络里启动临时 PostgreSQL、Redis 和 New API，恢复 dump，检查 `/api/status`，最后清理临时资源。

演练会恢复到临时 PostgreSQL 容器，检查关键 New API 表，然后清理临时容器。

## 必须保留的内容

- PostgreSQL 数据库：用户、root 账号、tokens、channels、settings、logs、billing、OAuth/payment 配置。
- `.env` 或 `.env.production`：保留 `POSTGRES_*`、`REDIS_PASSWORD`，尤其是 `SESSION_SECRET`。
- 如果 New API 在本地保存生成文件或资源，则保留 `data/new-api/`。

Redis 对缓存和会话类运行时状态有用，但关键恢复来源是 PostgreSQL 和 env 文件。

## 本地开发规则

普通删除容器是安全的：

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml down
```

这会保留 Docker named volumes。

不要执行下面命令，除非你明确要清空本地状态：

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml down -v
```

`down -v` 会删除 `lihan_ai_postgres_data`，也就是本地 New API 数据库。

## 生产基线

小规模收费服务至少需要：

- 每日 PostgreSQL 备份。
- 每次 New API 升级、支付配置或渠道配置变更前备份。
- 本地保留 14-30 天。
- 一个加密的离线副本，例如 restic over SFTP、S3-compatible object storage 或私有备份机。
- 每月在单独机器或临时 Docker project 上做恢复演练。

只有本地备份不够。如果 VPS 磁盘丢失，本地 dump 也会一起丢失。

## 离线 Restic 备份

生产 origin 准备好 `.env.production` 后，在 git 之外配置 restic 凭证：

```bash
export RESTIC_REPOSITORY=sftp:user@backup-host:/srv/restic/lihan-ai
export RESTIC_PASSWORD='<store outside the server>'
export CONFIG_SNAPSHOT_GPG_RECIPIENT='<optional-gpg-recipient>'
ENV_FILE=.env.production bash ops/offsite-backup.sh
```

wrapper 会创建 PostgreSQL dump、导出脱敏配置快照、可选导出 GPG 加密私有快照，用 restic 备份这些文件，执行保留策略，并运行 `restic check`。

`RESTIC_PASSWORD` 必须保存在生产服务器之外。没有它，离线仓库无法恢复。

## 建议 Cron

在 VPS 仓库目录中设置：

```cron
15 3 * * * cd /opt/lihan_ai && bash ops/backup-postgres.sh >> logs/backup.log 2>&1
```

然后运行 `ops/offsite-backup.sh`，或用你选择的加密备份工具同步 `backups/postgres/` 和 `.env.production` 到离线位置。不要把它们提交到 git。

## 恢复顺序

1. 准备一台新服务器。
2. Clone 仓库并初始化 submodules。
3. 恢复保存的 `.env.production`。
4. 启动 PostgreSQL 和 Redis。
5. 运行 `bash ops/restore-postgres.sh <backup.dump>`。
6. 启动 New API。
7. 验证登录、后台设置、token 列表、渠道列表和 `/api/status`。
