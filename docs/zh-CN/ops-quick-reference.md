# 运维快速命令

这是生产 origin 的日常命令速查表。README 保留项目概览和最常见示例；每天值班、主动检查、发布、备份校验、恢复演练时，优先照这个文件执行。

## 前提

- 生产 origin 根目录：`/opt/lihan_ai_deploy/current`。
- 共享生产状态：`/opt/lihan_ai_deploy/shared`。
- 生产环境文件：`/opt/lihan_ai_deploy/shared/.env.production`，通常会从 `current/.env.production` 看到。
- 当前生产主机示例：`lihan@srv998135.hstgr.cloud`。
- 服务器是 Arch Linux。用 `cronie`、`pacman`、`systemctl enable --now cronie`；不要用 Debian 的 `apt` 或 `cron` 服务名。
- 当前 restic 可以先用本地仓库，例如 `RESTIC_REPOSITORY=/opt/lihan_ai_deploy/shared/restic-repo`。真正异地备份以后再迁移，不阻塞现在的日常运维。

## 每日快速检查

在生产服务器上执行：

```bash
cd /opt/lihan_ai_deploy/current

cat logs/production-monitor-runtime.status
cat logs/production-monitor-audit.status
cat logs/ops-health/status.json | grep -n 'overall_status\|runtime\|backup\|offsite\|audit\|restore_drill\|inode_status'
```

正常预期：

- `runtime`、`backup`、`offsite`、`audit`、`restore_drill` 都是 `PASS`。
- `overall_status` 是 `PASS`；如果是 `WARN`，必须能解释清楚是哪一个已知非故障 warning。
- 当前 Arch 文件系统上，`df -Pi /opt/lihan_ai_deploy/current` 可能把 `IUse%` 报成 `-`；健康报告会显示 `inode_status=WARN` 和 `inode_used_percent=0`。这代表 inode 使用率不可用，不代表 inode 满了。

只有 inode warning 时，看原始输出：

```bash
df -Pi /opt/lihan_ai_deploy/current
cat logs/ops-health/status.json | grep -n 'WARN\|inode_status\|inode_used_percent'
```

## 自动运维

cron 由操作员安装，仓库不会自动写 crontab。Arch Linux 上检查：

```bash
command -v crontab
systemctl is-enabled cronie
systemctl is-active cronie
EDITOR=nano crontab -e
crontab -l
```

如果缺 `cronie`：

```bash
sudo pacman -S --needed cronie
sudo systemctl enable --now cronie
```

生产 crontab：

```cron
*/5 * * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh runtime
*/15 * * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh audit
15 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh backup
35 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh offsite
20 4 1 * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/production-monitor.sh restore-drill
```

不要把 `restic snapshots`、`du -sh`、`. .env.production` 这类交互排查命令写进 crontab。它们只在人工 shell 里执行。

## 手动监控命令

在生产服务器上执行：

```bash
cd /opt/lihan_ai_deploy/current

ENV_FILE=.env.production bash ops/production-monitor.sh runtime
ENV_FILE=.env.production bash ops/production-monitor.sh backup
ENV_FILE=.env.production bash ops/production-monitor.sh offsite
ENV_FILE=.env.production bash ops/production-monitor.sh restore-drill
ENV_FILE=.env.production bash ops/production-monitor.sh audit
ENV_FILE=.env.production bash ops/ops-health-report.sh render
```

常用只读检查：

```bash
ENV_FILE=.env.production bash ops/check-production-runtime.sh
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker compose -p lihan_ai ps
tail -n 160 logs/production-monitor-runtime.log
tail -n 160 logs/production-monitor-audit.log
```

## Ops Dashboard 和 Kuma

Ops Dashboard 只监听本机回环，通过 SSH 隧道看：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/ops-dashboard.sh open
ssh -L 3021:127.0.0.1:3021 lihan@srv998135.hstgr.cloud
```

打开 `http://127.0.0.1:3021`，用完关闭服务端监听：

```bash
ENV_FILE=.env.production bash ops/ops-dashboard.sh close
```

Kuma admin UI 也只临时打开：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/kuma-ui.sh open
ssh -L 3011:127.0.0.1:3011 lihan@srv998135.hstgr.cloud
```

打开 `http://127.0.0.1:3011`，用完关闭：

```bash
ENV_FILE=.env.production bash ops/kuma-ui.sh close
```

## 发布最新 main

在本地仓库执行：

```bash
git fetch origin
git switch main
git pull --ff-only origin main

DEPLOY_HOST=lihan@srv998135.hstgr.cloud DEPLOY_REF=main bash ops/deploy-release.sh prepare
DEPLOY_HOST=lihan@srv998135.hstgr.cloud bash ops/deploy-release.sh smoke
DEPLOY_HOST=lihan@srv998135.hstgr.cloud bash ops/deploy-release.sh promote
DEPLOY_HOST=lihan@srv998135.hstgr.cloud bash ops/verify-remote-prod.sh
```

release 命令默认从远端 `.env.production` 读取 CPA 和 Cloudflare Tunnel 拓扑。只有明确临时覆盖时才传 `DEPLOY_INCLUDE_*`。

## 回滚代码版本

回滚只切换 release symlink 和 Compose 定义，不恢复数据库内容。

```bash
DEPLOY_HOST=lihan@srv998135.hstgr.cloud bash ops/deploy-release.sh rollback
DEPLOY_HOST=lihan@srv998135.hstgr.cloud bash ops/verify-remote-prod.sh
```

只有数据本身坏了，并且已经做出恢复决策时，才走数据库恢复。

## 手动备份

优先用 monitor wrapper，这样状态文件和看板会同步更新：

```bash
cd /opt/lihan_ai_deploy/current

ENV_FILE=.env.production bash ops/production-monitor.sh backup
ENV_FILE=.env.production bash ops/production-monitor.sh offsite
ENV_FILE=.env.production bash ops/production-monitor.sh audit
```

人工执行 restic 前必须导出 env。只 `. .env.production` 不会把 `RESTIC_REPOSITORY`、`RESTIC_PASSWORD` 导出给 `restic` 子进程。

```bash
cd /opt/lihan_ai_deploy/current
set -a; . ./.env.production; set +a
restic snapshots
restic check
du -sh /opt/lihan_ai_deploy/shared/restic-repo
```

如果 `restic snapshots` 提示没有 repository location，重新执行 `set -a; . ./.env.production; set +a`，并确认 `RESTIC_REPOSITORY` 已设置。

## 恢复演练

恢复演练不能碰生产数据库：

```bash
cd /opt/lihan_ai_deploy/current
latest="$(find backups/postgres -type f -name '*.dump' | sort | tail -n 1)"
ENV_FILE=.env.production bash ops/drill-restore-stack.sh "$latest"
ENV_FILE=.env.production bash ops/production-monitor.sh restore-drill
ENV_FILE=.env.production bash ops/production-monitor.sh audit
```

## 真实数据库恢复

这是破坏性操作。只在明确恢复窗口内执行，并且必须先选定可靠 dump，接受该 dump 时间点之后的数据丢失。

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/restore-postgres.sh backups/postgres/<backup>.dump
ENV_FILE=.env.production bash ops/check-production-runtime.sh
ENV_FILE=.env.production bash ops/production-monitor.sh audit
```

## 2026-05-11 经验教训

- release 目录模型下，编辑 `/opt/lihan_ai_deploy/shared/.env.production`。除非确认 symlink，否则不要把 release-local env 当成源头。
- 人工使用 restic 前，先执行 `set -a; . ./.env.production; set +a`，再跑 `restic snapshots` 或 `restic check`。
- `audit=FAIL` 可能只是 `runtime` stale；先看 cron 是否装好、`cronie` 是否 active。
- `offsite=FAIL` 且提示 `RESTIC_PASSWORD is not set`，优先查 `.env.production` 和导出方式，不要先怀疑 restic。
- Arch Linux 用 `cronie`；`crontab` 命令存在不代表当前用户已经有 crontab。
- `df -Pi` 的 `IUse%` 是 `-` 时，`inode_status=WARN` 是指标不可用，不是 inode 用满。
- 本地 restic 现在可以接受，但它只能防同机上的应用或数据库误操作。真正 off-server backup 是后续加固项。
