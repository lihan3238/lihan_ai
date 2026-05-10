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
