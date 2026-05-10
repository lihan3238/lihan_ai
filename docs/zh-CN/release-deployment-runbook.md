# Release 部署 Runbook

这是生产 origin 的推荐部署方式。它使用 Capistrano 风格的目录结构和 Git worktree，把 Git 更新、候选版本测试和正在运行的生产目录分开。

## 目录模型

默认根目录：

```text
/opt/lihan_ai_deploy/
  repo.git/
  releases/
  current -> releases/<release-id>
  previous -> releases/<previous-release-id>
  shared/
    .env.production
    data/cpa/
    logs/
    backups/
    snapshots/
```

规则：

- `main` 仍然是生产分支。生产 release 部署默认拒绝非 `main` ref，只有已记录的紧急情况才设置 `ALLOW_NON_MAIN_PROD_DEPLOY=1`。
- `git fetch`、候选 release 创建和候选 smoke 测试都不修改 `current`。
- Docker Compose 永远从 `current` 运行，并固定使用 `docker compose -p "$DEPLOY_COMPOSE_PROJECT"`。
- 运行时文件放在 `shared/`，不放在某个 release checkout 里。
- 本方案不追求零停机。`promote` 会切换 `current` 并重启 Compose stack。
- PM2 和 Paru 已评估过部署/回滚心智，但不作为核心依赖。本仓库保持 Shell 脚本 + Docker + Git 的控制面。

## 环境变量

生产默认值：

```env
DEPLOY_ROOT=/opt/lihan_ai_deploy
DEPLOY_REF=main
DEPLOY_COMPOSE_PROJECT=lihan_ai
DEPLOY_INCLUDE_CPA=0
RELEASE_KEEP=5
```

如果启用 CPA，把 CPA 运行时文件放到 shared：

```env
DEPLOY_INCLUDE_CPA=1
CPA_CONFIG_PATH=/opt/lihan_ai_deploy/shared/data/cpa/config.yaml
CPA_AUTH_PATH=/opt/lihan_ai_deploy/shared/data/cpa
CPA_LOG_PATH=/opt/lihan_ai_deploy/shared/logs/cpa
```

`docker-compose.cpa.ui.yml` 不进入默认 promote。只有需要临时管理 UI 时，按 `docs/zh-CN/cpa-runbook.md` 通过 SSH 隧道短时间启用。

## 从开发到生产

正常变更流程：

1. 在 WSL 或其他 Linux-like 环境本地开发。
2. 在短生命周期分支提交，例如 `codex/<topic>` 或 `feature/<topic>`。
3. 创建 PR，review 和检查通过后合并到 `main`。
4. 从本地仓库对 `DEPLOY_REF=main` 运行 `prepare`。
5. 对准备好的 `RELEASE_ID` 运行 `smoke`；需要固定备份时设置 `SMOKE_BACKUP_PATH`。
6. 只有 smoke 通过后才运行 `promote`。
7. 验证 `current`、Docker 服务、备份、New API 后台、CPA 渠道和 Kuma。

生产服务器不再作为开发工作目录使用。迁移窗口内可以短期保留旧的 `/opt/lihan_ai` clone，但生产应从 `/opt/lihan_ai_deploy/current` 运行。

## Bootstrap

从本地执行一次：

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh bootstrap
```

`bootstrap` 会创建 `DEPLOY_ROOT`、初始化 `repo.git`、创建 `shared/`，并从 `LEGACY_DEPLOY_PATH` 复制缺失的运行时文件。`LEGACY_DEPLOY_PATH` 默认是 `/opt/lihan_ai`。

执行后检查或编辑：

```bash
sudo ls -la /opt/lihan_ai_deploy/shared
sudo nano /opt/lihan_ai_deploy/shared/.env.production
```

如果复制过来的 env 仍然把 CPA 指向 `/opt/lihan_ai`，在设置 `DEPLOY_INCLUDE_CPA=1` 前改成 `/opt/lihan_ai_deploy/shared/...`。

在 release 部署、备份和 rollback 都验证稳定前，先保留旧的 `/opt/lihan_ai` 目录。

如果 `/opt/lihan_ai_deploy/shared/data/cpa/config.yaml` 被 Docker bind mount 误创建成目录，先停止并删除 `relay-cpa`，把该路径替换成真实的 CPA `config.yaml` 文件，然后再启动 CPA。这个路径必须是文件，不是目录。

## Prepare

创建候选 release，不影响生产：

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> DEPLOY_REF=main bash ops/deploy-release.sh prepare
```

`prepare` 会 fetch 指定 ref，在 `releases/<timestamp>-<sha>` 下创建 detached worktree，初始化 submodule，链接 shared 运行时路径，运行 `ops/preflight.sh`，并渲染 Compose config。

记下输出里的 `RELEASE_ID`：

```text
RELEASE_ID=20260510T120000Z-abcdef0
```

## Smoke

用隔离恢复栈测试候选 release：

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> RELEASE_ID=<release-id> bash ops/deploy-release.sh smoke
```

`smoke` 默认使用最新的 `shared/backups/postgres/*.dump`，也可以通过 `SMOKE_BACKUP_PATH` 指定 dump。它会运行 `ops/drill-restore-stack.sh`，在独立 Docker network 中启动临时 PostgreSQL、Redis 和 New API。它不连接生产数据库，也不绑定公网端口。

## Promote

发布已测试的 release：

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> RELEASE_ID=<release-id> bash ops/deploy-release.sh promote
```

`promote` 会在存在当前生产 stack 时先备份 PostgreSQL，把 `previous` 指向旧 release，原子切换 `current`，然后运行：

```bash
docker compose -p lihan_ai --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d --remove-orphans
```

并验证 New API `/api/status`。如果 `DEPLOY_INCLUDE_CPA=1`，会追加 `docker-compose.cpa.yml`。如果发布失败，脚本会把 `current` 切回上一版，并尝试重启上一版 stack。

## Rollback

回滚到上一条成功 release：

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh rollback
```

Rollback 只切换代码和 Compose 定义，不恢复数据库状态。如果失败 release 已经写入数据，先导出当前数据库用于审计，再恢复已知可用的 PostgreSQL dump。

## 查看和清理

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh list
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh current
DEPLOY_HOST=<deploy-user>@<origin-host> RELEASE_KEEP=5 bash ops/deploy-release.sh cleanup
```

`cleanup` 保留最新 release 以及 `current`、`previous`，删除更旧 worktree，并清理 `repo.git` 的 worktree 元数据。

## Promote 后验收

每次生产 promote 后运行这些检查：

```bash
readlink -f /opt/lihan_ai_deploy/current

cd /opt/lihan_ai_deploy/current
docker compose -p lihan_ai --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  ps

ENV_FILE=.env.production bash ops/check-production-runtime.sh

backup="$(ENV_FILE=.env.production bash ops/backup-postgres.sh)"
echo "$backup"
ENV_FILE=.env.production bash ops/verify-postgres-backup.sh "$backup"

docker logs --tail=80 relay-cpa
```

验证 New API 能通过 Docker 内网访问 CPA：

```bash
docker exec relay-new-api wget -q -O - http://cli-proxy-api:8317/v1/models \
  --header="Authorization: Bearer <CPA_API_KEY>"
```

`<CPA_API_KEY>` 使用 CPA `api-keys` 中的一个值。

## 旧目录清理

第一次成功 promote 后不要立刻删除旧目录。

迁移期间常见目录：

```text
/opt/containerd           container runtime 数据，不要动
/opt/lihan_ai             legacy 直接 Git checkout，验证稳定后归档
/opt/lihan_ai_deploy      当前 release 部署根目录
/opt/lihan_ai_runtime     旧 ad hoc CPA runtime，CPA 迁移后再归档
```

归档旧目录前必须满足：

- `readlink -f /opt/lihan_ai_deploy/current` 指向你期望运行的 release。
- `docker compose -p lihan_ai ... ps` 显示 New API、Caddy、PostgreSQL、Redis、Uptime Kuma 和 CPA 按预期 healthy 或 running。
- 从 `/opt/lihan_ai_deploy/current` 运行 `ENV_FILE=.env.production bash ops/backup-postgres.sh` 成功。
- CPA 配置和 auth 文件已经位于 `/opt/lihan_ai_deploy/shared/data/cpa`。
- `docker inspect relay-cpa` 不再显示任何 `/opt/lihan_ai_runtime` 挂载。
- 迁移后至少完整跑通过一次 release deploy、smoke、promote 和 backup。

检查 CPA 挂载：

```bash
docker inspect relay-cpa --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
```

先改名归档，稳定后再删除：

```bash
sudo mv /opt/lihan_ai /opt/lihan_ai.legacy-$(date +%Y%m%d)
sudo mv /opt/lihan_ai_runtime /opt/lihan_ai_runtime.legacy-$(date +%Y%m%d)
```

观察几天稳定后，确认没有 mount、cron 或操作流程引用旧目录，再删除归档目录。不要删除 `/opt/containerd`，清理时也不要运行 `docker compose down -v`。

## 新机器或灾难恢复

新机器恢复先按 `docs/zh-CN/disaster-recovery-runbook.md` 执行。

release 相关恢复概要：

1. 准备 Docker 和 deploy 用户。
2. 创建 `/opt/lihan_ai_deploy` 并把 owner 改给 deploy 用户。
3. 运行 `ops/deploy-release.sh bootstrap`。
4. 恢复 `/opt/lihan_ai_deploy/shared/.env.production`、CPA runtime 文件和 PostgreSQL dumps。
5. 对 `main` 运行 `prepare`。
6. 用 `SMOKE_BACKUP_PATH` 指向已知 dump 运行 `smoke`。
7. promote release 启动 stack。
8. 如果是完整灾难恢复，恢复选定的 PostgreSQL dump。
9. DNS 切换或付费流量恢复前，跑完 promote 后验收检查。

## 运维说明

备份和运行时检查从 `current` 执行：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-postgres.sh
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

cron 日志写入 shared：

```cron
15 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/backup-postgres.sh >> /opt/lihan_ai_deploy/shared/logs/backup.log 2>&1
```

部署或回滚时不要运行 `docker compose down -v`。PostgreSQL 和 Redis 继续使用 Docker named volumes。
