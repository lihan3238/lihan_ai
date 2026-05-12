# Lihan AI Relay

English: [README.md](README.md)

本仓库是上游 New API 的轻量生产 wrapper。运行时继续使用官方 `calciumion/new-api:latest` 镜像；本地代码负责部署、备份、恢复、迁移、验收和运维文档。

## 边界

- 上游源码以 submodule 保存在 `vendor/new-api`。
- 生产部署保持 Docker Compose。
- 直连源站模式由 Caddy 接公网流量；Cloudflare Tunnel 模式由 `cloudflared` 接入。
- CPA / CLIProxyAPI 是可选内部服务，只给 Docker 内网使用。
- 当前运维面已经下线旧的监控、看板和远端备份链路。
- 在确认 New API 原生能力不足前，不急于做本地业务二开。

## 快速开始

1. 使用 WSL Ubuntu 24.04 或 Linux VPS shell。
2. 安装 Docker 和 Docker Compose。
3. 初始化 submodule：

```bash
git submodule update --init --recursive
```

4. 复制 `.env.production.example` 为 `.env.production`。
5. 替换所有 `CHANGE_ME`，并把 `DOMAIN` 设置为生产公网域名。
6. 运行预检：

```bash
ENV_FILE=.env.production bash ops/preflight.sh
```

7. 启动基础生产栈：

```bash
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d
```

8. 打开 `https://$DOMAIN`，创建第一个 New API 管理员账号，然后在上游后台完成配置。

## 仓库结构

- `docker-compose.yml`：New API、PostgreSQL、Redis 和 Caddy。
- `docker-compose.prod.yml`：生产日志和端口覆盖。
- `docker-compose.cpa.yml`：可选 CPA 内部服务。
- `docker-compose.cpa.ui.yml`：只用于 SSH 隧道的短时 CPA 管理 UI 覆盖。
- `docker-compose.cloudflare-tunnel.yml`：可选 Cloudflare Tunnel 路径，运行 `cloudflared` 并跳过源站公网 `80/443`。
- `.env.example`：本地开发变量样板。
- `.env.production.example`：生产 env 样板。
- `ops/`：预检、部署、备份、恢复、迁移、CPA 和 env 对齐脚本。
- `tests/`：wrapper 的 shell 测试。
- `docs/`：英文 runbook；`docs/zh-CN/` 是同步中文文档。
- `config/ops-profiles/`：只读 New API 配置验收 profile。
- `vendor/new-api`：上游 New API 源码。

## 生产常用命令

日常运维优先用薄封装入口：

```bash
ENV_FILE=.env.production bash ops/relayctl.sh status
ENV_FILE=.env.production bash ops/relayctl.sh maintain
bash ops/relayctl.sh release-check
```

这个入口只调用现有脚本，不改变生产安全边界：GitHub Actions 只验证仓库，生产 promote 仍然人工执行。维护者流程见 [docs/zh-CN/maintainer-release-runbook.md](docs/zh-CN/maintainer-release-runbook.md)。

给内测用户先发 [docs/zh-CN/user-quickstart.md](docs/zh-CN/user-quickstart.md)，需要细节时再发 [docs/zh-CN/user-guide.md](docs/zh-CN/user-guide.md)。社区 PR 规则见 [CONTRIBUTING.md](CONTRIBUTING.md)。

### 初始生产部署

源站已有 Docker、SSH 访问，并准备好 `/opt/lihan_ai_deploy/shared/.env.production` 后，从本地仓库执行：

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh bootstrap
DEPLOY_HOST=<deploy-user>@<origin-host> DEPLOY_REF=main bash ops/deploy-release.sh prepare
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh smoke
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh promote
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh status
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/verify-remote-prod.sh
```

`prepare` 会在远端记录 `candidate`，所以正常 `smoke` 和 `promote` 不需要手动填 `RELEASE_ID`。Release 命令默认从远端 `.env.production` 读取 CPA 和 Cloudflare Tunnel 拓扑；只有临时覆盖时才传 `DEPLOY_INCLUDE_*`。

`prepare` 在预检前会执行：

```bash
bash ops/sync-env-template.sh /opt/lihan_ai_deploy/shared/.env.production .env.production.example
```

这个同步只把 release 样板里新增而生产 env 缺失的键追加进去；它会先创建 `.bak.<UTC>` 备份，不覆盖已有值，不删除废弃键，只报告废弃键。

### 更新最新 main 到生产

```bash
git fetch origin
git switch main
git pull --ff-only origin main

DEPLOY_HOST=<deploy-user>@<origin-host> DEPLOY_REF=main bash ops/deploy-release.sh prepare
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh smoke
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/deploy-release.sh promote
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/verify-remote-prod.sh
```

只有明确操作某个旧 release 时，才使用 `RELEASE_ID=<release-id>`。
如果 promote 过程中 SSH 断开，先运行 `ops/deploy-release.sh status`；如果没有 worker 在运行且 `promote.state` 已陈旧，再运行 `ops/deploy-release.sh recover`。

### 打开和关闭 CPA UI

CPA UI 只通过 SSH 隧道临时访问。

生产服务器上：

```bash
cd /opt/lihan_ai_deploy/current
ops/cpa-ui.sh open
ops/cpa-ui.sh ps
```

本地机器上：

```bash
ssh -L 8317:127.0.0.1:8317 <deploy-user>@<origin-host>
```

打开 `http://127.0.0.1:8317/management.html`。用完后关闭：

```bash
cd /opt/lihan_ai_deploy/current
ops/cpa-ui.sh close
ops/cpa-ui.sh ps
```

### 本地备份 Cron

仓库当前只保留一个定时生产任务：创建 PostgreSQL dump 并立即校验。

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-cron.sh
```

建议 crontab：

```cron
15 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/backup-cron.sh
```

备份默认写入 `backups/postgres/`。手动下载：

```bash
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump .
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump.sha256 .
```

恢复和演练仍然人工执行：

```bash
ENV_FILE=.env.production bash ops/verify-postgres-backup.sh backups/postgres/<dump>.dump
ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<dump>.dump
ENV_FILE=.env.production bash ops/restore-postgres.sh backups/postgres/<dump>.dump
```

## New API 分组

生产只保留两个 New API 分组：

- `default`：普通朋友/用户默认组。
- `vip`：人工授予的高优先级或优惠组。

仓库不再把 `standard` 当作当前分组。生产数据库不会由代码自动迁移；请在 New API 后台手动把旧 `standard` 用户、token、渠道能力、价格和模型权限迁到 `default`，`vip` 只保留给明确授予的人。

只读验收：

```bash
bash ops/validate-ops-profile.sh config/ops-profiles/glm-default.example.json
bash ops/channel-health-advisor.sh config/ops-profiles/glm-default-health.example.json
```

## Small Circle Launch

配置朋友小范围套餐时看 [docs/zh-CN/new-api-small-circle-launch-runbook.md](docs/zh-CN/new-api-small-circle-launch-runbook.md)。
第一阶段只做后台配置：station quota / 站内额度文案、New API 订阅计划、manual activation、fair use，以及官方镜像优先的前端策略。
熟人内测宣发、微信群/QQ群运营、朋友圈/QQ 空间文案、开通私聊模板和故障反馈模板见 [docs/zh-CN/new-api-small-circle-promo-ops.md](docs/zh-CN/new-api-small-circle-promo-ops.md)。
上游 New API `v1.0.0-rc.5` 已包含后台 dropdown 修复；本机 E2E 通过后，生产默认运行
`calciumion/new-api:latest`，并保持 `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=0`。
pin 住的 `lihan3238/new-api` 补丁镜像只作为 rollback 路径保留：如果官方 latest 未通过
后台 E2E，才临时设置 `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1`、
`DEPLOY_LOCAL_NEW_API_BUILD_MODE=pull` 和非官方 `LOCAL_NEW_API_IMAGE`。

开始售卖套餐前，先验证手动开通依赖的新前端后台按钮：

```bash
NEW_API_BASE_URL=https://api.lihan3238.com \
NEW_API_ADMIN_USERNAME=<admin> \
NEW_API_ADMIN_PASSWORD=<password> \
bash ops/check-new-api-admin-frontend.sh
```

## 常用命令

```bash
docker compose ps
docker compose logs -f new-api
ENV_FILE=.env.production bash ops/check-production-runtime.sh
ENV_FILE=.env.production bash ops/backup-postgres.sh
ENV_FILE=.env.production bash ops/backup-cron.sh
ENV_FILE=.env.production bash ops/prune-runtime-storage.sh all
bash ops/phase1-smoke-test.sh
bash ops/relay-diagnostics.sh
NEW_API_TEST_TOKEN=... NEW_API_TEST_MODEL=glm-5.1 bash ops/e2e-api-billing.sh
bash ops/export-config-snapshot.sh
SOURCE_SSH=root@old TARGET_SSH=root@new bash ops/migration-preflight.sh
CONFIRM_FINAL_CUTOVER=yes SOURCE_SSH=root@old TARGET_SSH=root@new bash ops/migrate-prod.sh
bash ops/sync-cpa-upstream-assets.sh
```

## 本地开发

```bash
cp .env.example .env
# 先替换 CHANGE_ME
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml up -d new-api
```

打开 `http://localhost:$NEW_API_DEV_PORT`。本地默认端口是 `3100`；容器内 New API 仍监听 `3000`。不要运行 `docker compose down -v`，除非明确要删除本地数据库状态。

浏览器 E2E 见 `docs/browser-e2e-runbook.md`。重新跑本地浏览器或 API 流程前，先执行：

```bash
bash ops/check-local-ports.sh
```

## CI 和验证

`.github/workflows/ci.yml` 是 GitHub Actions PR CI。它运行不需要 secrets 的 PR 检查：shell 语法、shell 测试、Compose 渲染、文档检查和 `scripts/verify-repo.ps1 -SkipDocker`。

本地验证：

```bash
bash -n ops/*.sh tests/*.test.sh
for test in tests/*.test.sh; do bash "$test"; done
bash ops/dev-gate.sh
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File scripts\verify-repo.ps1 -SkipDocker
git diff --check
```

新功能可以把私有过程笔记放在已忽略的 `docs/ai-dev/<YYYY-MM-DD>-<topic>/`；需要本地校验笔记时运行 `bash ops/dev-gate.sh docs/ai-dev/<YYYY-MM-DD>-<topic>`。`E2E Coverage Matrix` 要保留在过程笔记或 PR/runbook handoff 里；耐久决策、E2E 证据、用户说明和剩余风险要写到 PR 描述或正式 runbook。跳过的 E2E 必须写 `Reason:` 和 `Rerun:`。
