# Lihan AI Relay

English: [README.md](README.md)

本仓库当前是一个干净的 New API 部署与研究工作区。第一个里程碑是先原样跑通上游 New API，理解它已有的用户、渠道、计费、日志和管理能力，再决定是否需要本地二开。

## 边界

- 运行时默认使用官方 `calciumion/new-api:latest` 镜像。
- 上游源码以 submodule 形式保存在 `vendor/new-api`。
- 本地开发优先使用 WSL。
- 生产部署保持 Docker 化。
- 在确认 New API 原生能力不足前，不急于增加自定义业务功能。

## 快速开始

1. 使用 WSL Ubuntu 24.04 或 Linux VPS shell。
2. 在 VPS 安装 Docker 和 Docker Compose。
3. 如果尚未拉取 New API submodule，先初始化：

```bash
git submodule update --init --recursive
```

4. 复制 `.env.production.example` 为 `.env.production`。
5. 替换所有 `CHANGE_ME`，并把 `DOMAIN` 设置为生产域名。
6. 把域名 A/AAAA 记录指向 VPS。
7. 运行预检：

```bash
ENV_FILE=.env.production bash ops/preflight.sh
```

8. 启动生产栈：

```bash
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d
```

9. 打开 `https://$DOMAIN`，创建第一个管理员账号，然后在 New API 原生后台完成配置。

## 仓库结构

- `docker-compose.yml`：New API、PostgreSQL、Redis、Caddy 和 Uptime Kuma。
- `docker-compose.prod.yml`：生产覆盖文件，用于日志轮转并移除开发端口。
- `docker-compose.edge.yml`：无状态 edge 反向代理。
- `docker-compose.cpa.yml`：可选 CPA 内部服务，给 New API 做上游适配。
- `docker-compose.cloudflare-tunnel.yml`：可选 Cloudflare Tunnel 源站路径，运行 `cloudflared` 并跳过公网 Caddy 端口。
- `.env.example`：本地开发变量示例。
- `.env.production.example`：生产 origin 和离线备份变量示例。
- `docs/zh-CN/`：部署和运维文档中文版。
- `docs/i18n-map.md`：中英文文档同步映射表。
- `docs/new-api-code-map.md`：上游 New API 源码和功能地图。
- `docs/new-api-full-research.md`：上游能力调研。
- `docs/phase1-new-api-validation-runbook.md`：一阶段 API/计费验证流程。
- `docs/local-development-state.md`：本地初始化和持久化状态规则。
- `docs/backup-strategy.md`：数据库备份、校验和恢复规则。
- `docs/server-buying-guide.md`：服务器规格和购买建议。
- `docs/production-deployment-runbook.md`：生产 origin 部署流程。
- `docs/release-deployment-runbook.md`：推荐的 `releases/current/shared` 生产部署流程。
- `docs/cloudflare-saas-runbook.md`：Cloudflare for SaaS custom hostname 和 Tunnel 源站流程。
- `docs/edge-proxy-runbook.md`：中国优化 edge 反代流程。
- `docs/migration-runbook.md`：无损迁移流程。
- `docs/disaster-recovery-runbook.md`：离线备份和灾难恢复流程。
- `docs/kuma-status-runbook.md`：Uptime Kuma 公开状态页配置。
- `docs/cpa-runbook.md`：可选 CPA 部署和 SSH 隧道管理 UI。
- `docs/development-workflow.md`：research-first 开发流程。
- `docs/templates/ai-dev/`：AI 辅助开发模板。
- `docs/spec-kit-integration-runbook.md`：GitHub Spec Kit Codex skills 集成说明。
- `.github/workflows/ci.yml`：不使用 secrets 的 GitHub Actions PR CI，用于脚本测试和 Compose 渲染。
- `.specify/`：Spec Kit 脚本、模板、工作流和 constitution memory。
- `.agents/skills/speckit-*`：Spec Kit 生成的 Codex skills。
- `docs/wrapper-infra-runbook.md`：wrapper 构建、快照、恢复演练和 production gate。
- `config/ops-profiles/`：可提交的只读运营配置 profile。
- `ops/`：预检、备份、恢复、部署和迁移脚本。
- `tests/`：轻量脚本测试。
- `scripts/verify-repo.ps1`：本地仓库结构校验。
- `vendor/new-api`：上游 New API 源码 submodule。

## 常用命令

```bash
docker compose ps
docker compose logs -f new-api
bash ops/backup-postgres.sh
bash ops/phase1-smoke-test.sh
bash ops/relay-diagnostics.sh
NEW_API_TEST_TOKEN=... NEW_API_TEST_MODEL=glm-5.1 bash ops/e2e-api-billing.sh
bash ops/live-e2e-billing-from-db-token.sh <test-token-name>
bash ops/export-config-snapshot.sh
bash ops/validate-ops-profile.sh config/ops-profiles/glm-standard.example.json
bash ops/channel-health-advisor.sh config/ops-profiles/glm-standard-health.example.json
bash ops/drill-restore-postgres.sh backups/postgres/<backup>.dump
bash ops/bootstrap-server.sh
DEPLOY_HOST=root@x.x.x.x bash ops/deploy-release.sh prepare
DEPLOY_HOST=root@x.x.x.x bash ops/deploy-release.sh smoke
DEPLOY_HOST=root@x.x.x.x bash ops/deploy-release.sh promote
DEPLOY_HOST=root@x.x.x.x bash ops/deploy-prod.sh
DEPLOY_HOST=root@x.x.x.x bash ops/verify-remote-prod.sh
ENV_FILE=.env.production bash ops/offsite-backup.sh
SOURCE_SSH=root@old TARGET_SSH=root@new bash ops/migration-preflight.sh
ENV_FILE=.env.production bash ops/check-production-runtime.sh
bash ops/sync-cpa-upstream-assets.sh
```

## Spec Kit 工作流

GitHub Spec Kit `v0.8.7` 已按 Codex skills 模式初始化。在仓库根目录可使用：

```text
$speckit-constitution
$speckit-specify
$speckit-plan
$speckit-tasks
$speckit-implement
```

Spec Kit 负责帮助产出 spec、plan 和 tasks，但仓库级门禁仍然有效。计划性工作需要在 `docs/ai-dev/<YYYY-MM-DD>-<topic>/` 下保留 feature 文档，通过 `bash ops/ai-dev-check.sh <feature-dir>`，涉及运维或计费风险的变更还需要走 `ops/production-gate.sh`。

## 本地开发

本地开发运行原版 New API Docker 镜像，并直接暴露到 localhost 方便检查：

```bash
cp .env.example .env
# 先替换 CHANGE_ME
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml up -d new-api
```

打开 `http://localhost:$NEW_API_DEV_PORT`。本地默认端口是 `3100`，避免与常见的 `3000` 冲突；容器内 New API 仍监听 `3000`。开发覆盖文件默认绑定 `127.0.0.1`，避免把后台和 API key 暴露到局域网。确实需要局域网访问时，设置 `NEW_API_DEV_HOST=0.0.0.0` 并重建 `new-api` 容器，同时确认 Windows 防火墙只允许可信网络。

首次登录时，New API 会提示初始化系统并创建 root/admin。可以按提示操作。账号、设置、渠道、token 和支付配置存储在 PostgreSQL 中，容器重启或删除不会丢。不要运行 `docker compose down -v`，除非你明确要删除本地数据库。

## 生产与迁移

生产 origin 使用 `.env.production` 和 `docker-compose.prod.yml`。后续生产更新优先使用 `docs/zh-CN/release-deployment-runbook.md` 里的 release 流程：生产从 `/opt/lihan_ai_deploy/current` 运行，运行时文件放在 `/opt/lihan_ai_deploy/shared`。edge 反代使用 `docker-compose.edge.yml`，必须保持无状态：

```bash
ENV_FILE=.env.production bash ops/preflight.sh
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d
```

推荐的 release 部署和验证：

```bash
DEPLOY_HOST=root@x.x.x.x bash ops/deploy-release.sh prepare
DEPLOY_HOST=root@x.x.x.x bash ops/deploy-release.sh smoke
DEPLOY_HOST=root@x.x.x.x bash ops/deploy-release.sh promote
DEPLOY_HOST=root@x.x.x.x bash ops/verify-remote-prod.sh
```

`prepare` 会把最新准备好的 release 记录为 `candidate`，所以正常的 `smoke` 和 `promote` 不需要再手动复制 `RELEASE_ID`。只有明确要测试或发布某个旧 release 时，才额外设置 `RELEASE_ID=<release-id>`。

legacy 直接 checkout 部署仍保留：

```bash
DEPLOY_HOST=root@x.x.x.x DEPLOY_PATH=/opt/lihan_ai DEPLOY_REF=main bash ops/deploy-prod.sh
```

面向国内访问时，建议在 origin 前增加中国优化 edge VPS，并按 `docs/zh-CN/edge-proxy-runbook.md` 配置。未来迁移到新生产服务器时，按 `docs/zh-CN/migration-runbook.md` 执行。

如果需要把 CPA 作为 New API 后面的内部适配层，按 `docs/zh-CN/cpa-runbook.md` 操作。不要把 CPA `8317` 端口暴露到公网；管理 UI 使用 SSH 隧道访问。

Windows 上运行仓库校验：

```powershell
./scripts/verify-repo.ps1
```

浏览器级 E2E 参考 `docs/browser-e2e-runbook.md`。本地 Kuma 端口默认是 `3011`，避免常见的 `3001` 冲突。重启或跑浏览器流程前，先执行 `bash ops/check-local-ports.sh`。

如果 WSL 拉包或拉镜像需要使用 Windows 代理，可以临时设置：

```bash
export host_ip="$(grep nameserver /etc/resolv.conf | awk '{print $2}')"
export http_proxy="http://$host_ip:10808"
export https_proxy="$http_proxy"
```

如果 WSL gateway 地址不能用，可以使用已知可用的本地 fallback：

```bash
export HTTP_PROXY=http://10.88.0.6:10808
export HTTPS_PROXY=http://10.88.0.6:10808
export http_proxy=http://10.88.0.6:10808
export https_proxy=http://10.88.0.6:10808
```

不要把本地代理变量提交进 `.env`。

## Operations Profiles

当前第一个 wrapper 层运营能力是只读 GLM standard pool profile：

```bash
bash ops/validate-ops-profile.sh config/ops-profiles/glm-standard.example.json
```

它会检查当前 PostgreSQL 中是否存在启用的 `standard` 分组渠道并支持 `glm-5.1`，同时报告用户、token、订阅、支付相关配置和可选的 `/v1/models` 可见性。它不会创建或修改 New API 数据。只有想检查模型列表时才设置 `NEW_API_TEST_TOKEN`。

内部渠道健康检查：

```bash
bash ops/channel-health-advisor.sh config/ops-profiles/glm-standard-health.example.json
```

它只读 PostgreSQL，汇总渠道容量、近期错误、样本量、延迟、channel test 时间和操作建议，不会调用真实上游补全。

默认健康 profile 使用 `mode: development`，会把搭建期噪声错误和慢探测降级为 warning。正式收费前，复制 profile 并切到 `mode: production`，再收紧阈值。

用户侧状态页使用 Uptime Kuma。按 `docs/kuma-status-runbook.md` 发布粗粒度组件，例如 API Gateway、GLM Standard、Account & Billing、Maintenance Notice。
