# Release 部署 Runbook

这是推荐的生产部署模型。它把 Git 更新、候选版本验证、运行时文件和正在运行的生产目录分开。

## 目录模型

```text
/opt/lihan_ai_deploy/
  repo.git/
  releases/
  candidate -> releases/<prepared-release-id>
  current -> releases/<release-id>
  previous -> releases/<previous-release-id>
  state/
    promote.state
    promote.log
    promote.pid
    last_healthy -> releases/<last-healthy-release-id>
  shared/
    .env.production
    data/cpa/
    cloudflared/
    logs/
    backups/
    snapshots/
```

规则：

- 生产部署使用 `main`，除非为了已记录的紧急情况设置 `ALLOW_NON_MAIN_PROD_DEPLOY=1`。
- `prepare` 创建 detached Git worktree 并更新 `candidate`，不触碰 `current`。
- 正常 `smoke` 和 `promote` 在不传 `RELEASE_ID` 时自动使用 `candidate`。
- Compose 固定使用 `docker compose -p "$DEPLOY_COMPOSE_PROJECT"`。
- 运行时文件放在 `shared/`，不放在 release checkout 里。
- Promote 会重启 Docker Compose stack；这不是零停机部署。
- `promote` 会在远端作为受管 worker 执行。本地 SSH 断开时，worker 会继续在服务器上完成发布或回滚。
- `state/promote.state` 记录当前发布阶段；`state/last_healthy` 指向最后一次完整通过 runtime check 的 release。
- PM2 和 Paru 已考虑过，但生产控制面仍保持 shell、Git 和 Docker。

## Prepare 时的 Env 对齐

`prepare` 会在 preflight 前运行：

```bash
bash ops/sync-env-template.sh /opt/lihan_ai_deploy/shared/.env.production .env.production.example
```

同步会创建 `.bak.<UTC>` 备份，追加 `.env.production.example` 中存在但生产 env 缺失的键，保留已有值，并报告废弃键但不删除。`ops/preflight.sh` 仍会拦截 `CHANGE_ME` 占位值。

## 必需 Env

```env
DEPLOY_ROOT=/opt/lihan_ai_deploy
DEPLOY_REF=main
DEPLOY_COMPOSE_PROJECT=lihan_ai
DEPLOY_INCLUDE_CPA=0
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=0
DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=0
RELEASE_KEEP=5
```

临时 New API 前端补丁构建必须显式开启：

```env
DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1
LOCAL_NEW_API_IMAGE=lihan-ai/new-api:local
```

开启后会追加 `docker-compose.local-build.yml`，从当前 release pin 住的 `vendor/new-api` 构建 `new-api`，其它服务仍使用拉取的镜像。等官方 `calciumion/new-api:latest` 发布等价前端修复，并通过后台 E2E 后，把它改回 `0`。
临时补丁期间，`.gitmodules` 会把 `vendor/new-api` 指向 `lihan3238/new-api`，这样 CI 和生产 release worker 都能拉到 pin 住的修复 commit。

CPA 运行时文件应放在 shared：

```env
DEPLOY_INCLUDE_CPA=1
CPA_CONFIG_PATH=/opt/lihan_ai_deploy/shared/data/cpa/config.yaml
CPA_AUTH_PATH=/opt/lihan_ai_deploy/shared/data/cpa
CPA_LOG_PATH=/opt/lihan_ai_deploy/shared/logs/cpa
```

Cloudflare Tunnel 运行时文件也放在 shared：

```env
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1
CLOUDFLARED_CONFIG_PATH=/opt/lihan_ai_deploy/shared/cloudflared/config.yml
CLOUDFLARED_CREDENTIALS_PATH=/opt/lihan_ai_deploy/shared/cloudflared/tunnel.json
```

两个 tunnel 路径必须是普通文件：

```bash
test -f /opt/lihan_ai_deploy/shared/cloudflared/config.yml && echo "config.yml is file"
test -f /opt/lihan_ai_deploy/shared/cloudflared/tunnel.json && echo "tunnel.json is file"
```

Tunnel 模式会追加 `docker-compose.cloudflare-tunnel.yml` 并把 Caddy 缩容为 0，所以源站不再需要公网 `80/443`。

## 从开发到生产

1. 在 `codex/<topic>` 这样的短生命周期分支本地开发。
2. 创建 PR，检查通过后合并到 `main`。
3. 对 `DEPLOY_REF=main` 运行 `prepare`。
4. 运行 `smoke`；需要指定 dump 时传 `SMOKE_BACKUP_PATH`。
5. Smoke 通过后才运行 `promote`。
6. 验证 runtime、备份、New API 后台、测试 token、可选 CPA 路由和可选 tunnel 路由。

生产服务器不应作为开发工作目录。迁移期间可以短期保留旧 `/opt/lihan_ai` clone，但生产应从 `/opt/lihan_ai_deploy/current` 运行。

## Bootstrap

从本地机器执行一次：

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh bootstrap
```

`bootstrap` 会创建 `DEPLOY_ROOT`、初始化 `repo.git`、创建 `shared/`，并从 `LEGACY_DEPLOY_PATH` 复制缺失的运行时文件。`LEGACY_DEPLOY_PATH` 默认是 `/opt/lihan_ai`。

Bootstrap 后：

```bash
sudo ls -la /opt/lihan_ai_deploy/shared
sudo nano /opt/lihan_ai_deploy/shared/.env.production
```

如果 CPA config 从 `/opt/lihan_ai_runtime` 迁移过来，确认 `.env.production` 已指向 `/opt/lihan_ai_deploy/shared/data/cpa`。

## Prepare、Smoke、Promote

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> DEPLOY_REF=main bash ops/deploy-release.sh prepare
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh smoke
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh promote
```

随时查看发布状态：

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh status
```

如果 promote 过程中 SSH 断开，先运行 `status`。如果没有 worker 在运行，但 `promote.state` 残留，再运行：

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh recover
```

`recover` 会在当前 release 健康时接受当前版本；如果当前不健康，则回滚到 `previous`，再不行就回退到 `last_healthy`。这只回滚代码和 Compose，不恢复数据库内容。

只有明确需要操作某个旧 prepared release 时才传：

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> RELEASE_ID=<release-id> bash ops/deploy-release.sh smoke
DEPLOY_HOST=<deploy-user>@<origin-host> RELEASE_ID=<release-id> bash ops/deploy-release.sh promote
```

用指定备份 smoke：

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> \
SMOKE_BACKUP_PATH=/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump \
bash ops/deploy-release.sh smoke
```

## Promote 后验收

服务器上：

```bash
cd /opt/lihan_ai_deploy/current
readlink -f /opt/lihan_ai_deploy/current
COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh
ENV_FILE=.env.production bash ops/backup-cron.sh
curl -i https://api.lihan3238.com/api/status
```

New API 里确认：

- 管理后台能登录。
- `/api/status` 返回 success。
- 测试 token 可以调用 `/v1/models`。
- 当前业务分组只保留 `default` 和 `vip`。
- 如果启用 CPA，渠道指向 Docker 内部 CPA 地址。

## 旧目录清理

迁移期间这些目录可能共存：

```text
/opt/containerd           container runtime 数据，不要动
/opt/lihan_ai             legacy 直接 Git checkout，稍后归档
/opt/lihan_ai_deploy      当前 release 部署根目录
/opt/lihan_ai_runtime     旧 ad hoc CPA runtime，CPA 迁移后归档
```

归档旧目录前：

- `readlink -f /opt/lihan_ai_deploy/current` 指向预期 release。
- runtime 检查通过。
- `ENV_FILE=.env.production bash ops/backup-cron.sh` 通过。
- `ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<dump>.dump` 通过。
- CPA 文件位于 `/opt/lihan_ai_deploy/shared/data/cpa`。
- `docker inspect relay-cpa` 不显示 `/opt/lihan_ai_runtime` 挂载源。
- crontab 不再引用旧路径。

检查 CPA 挂载：

```bash
docker inspect relay-cpa --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
```

先归档：

```bash
sudo mv /opt/lihan_ai /opt/lihan_ai.legacy-$(date +%Y%m%d)
sudo mv /opt/lihan_ai_runtime /opt/lihan_ai_runtime.legacy-$(date +%Y%m%d)
```

稳定观察几天后再删除。不要删除 `/opt/containerd`，也不要用 `docker compose down -v` 做清理。

## 新服务器或灾难恢复

先执行 `docs/zh-CN/disaster-recovery-runbook.md`。Release 相关概要：

1. 准备 Docker 和 deploy 用户。
2. Bootstrap `/opt/lihan_ai_deploy`。
3. 恢复 `/opt/lihan_ai_deploy/shared/.env.production`。
4. 如使用 CPA 或 Cloudflare Tunnel，恢复对应运行时文件。
5. 把选定 PostgreSQL dump 复制到 `/opt/lihan_ai_deploy/shared/backups/postgres/`。
6. 运行 `prepare`，带 `SMOKE_BACKUP_PATH` 运行 `smoke`，然后 `promote`。
7. 用选定 dump 执行 `ops/restore-postgres.sh`。
8. DNS 或 tunnel 切换前跑 runtime 检查。

部署、回滚、清理或恢复期间都不要运行 `docker compose down -v`。
