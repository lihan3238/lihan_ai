# 运维 Runbook

## 首次部署

1. 使用 WSL Ubuntu 24.04 或 Linux VPS shell。
2. 运行 `git submodule update --init --recursive` 拉取固定版本的 New API 源码。
3. 复制 `.env.production.example` 为 `.env.production`。
4. 替换所有 `CHANGE_ME`。
5. 设置 `DOMAIN` 和 `ACME_EMAIL`。
6. 运行 `ENV_FILE=.env.production bash ops/preflight.sh`。
7. 运行 `docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d`。
8. 打开站点，创建管理员用户，并在 New API 原生后台配置系统。

生产环境跟踪 `main`。不要把长期功能分支部署到生产 origin；分支规则参考 `docs/zh-CN/git-branching-runbook.md`。

## New API 源码管理

默认部署使用官方 New API Docker 镜像，`vendor/new-api` 只用于审计、diff 和未来二开。新增本地业务逻辑前，必须先确认上游实现。更新固定的上游源码：

```bash
git -C vendor/new-api fetch origin
git -C vendor/new-api checkout origin/main
git add vendor/new-api
git commit -m "chore: update new-api upstream"
```

只有在自定义变更具备测试和回滚方案后，才把 `docker-compose.yml` 从官方镜像切换到本地构建镜像。

wrapper 层本地镜像、配置快照、恢复演练和 production gate 参考 `docs/wrapper-infra-runbook.md`。

生产部署、edge proxy、离线备份、服务器迁移和灾难恢复参考：

- `docs/production-deployment-runbook.md`
- `docs/edge-proxy-runbook.md`
- `docs/cpa-runbook.md`
- `docs/migration-runbook.md`
- `docs/disaster-recovery-runbook.md`
- `docs/git-branching-runbook.md`

## 本地开发

使用 WSL 执行开发命令。运行时使用 Docker，源码和配置在仓库中管理：

```bash
cp .env.example .env
# 先替换 CHANGE_ME
docker compose --env-file .env -f docker-compose.yml -f docker-compose.dev.yml up -d new-api
```

这会启动 PostgreSQL、Redis 和 New API，并在 `http://localhost:$NEW_API_DEV_PORT` 暴露 New API。默认本地端口是 `3100`；容器内 New API 仍监听 `3000`。生产环境应使用基础 `docker-compose.yml` 并通过 Caddy 访问 `https://$DOMAIN`。

如果需要本地 Uptime Kuma，除非确认 `3001` 空闲，否则使用 `3011`：

```powershell
$env:KUMA_PORT="3011"
docker compose --env-file .env -f docker-compose.yml up -d uptime-kuma
```

重启本地服务或运行浏览器 E2E 前检查端口：

```bash
bash ops/check-local-ports.sh
```

## WSL 网络代理

如果包下载或镜像拉取需要 Windows 代理，只在当前 WSL shell 中设置：

```bash
export host_ip="$(grep nameserver /etc/resolv.conf | awk '{print $2}')"
export http_proxy="http://$host_ip:10808"
export https_proxy="$http_proxy"
```

如果 WSL gateway 地址不可用，使用已知可用 fallback：

```bash
export HTTP_PROXY=http://10.88.0.6:10808
export HTTPS_PROXY=http://10.88.0.6:10808
export http_proxy=http://10.88.0.6:10808
export https_proxy=http://10.88.0.6:10808
```

不要把本地代理值写入 `.env`、`docker-compose.yml` 或提交配置。

## 初始后台探索

每个新功能或运维变更前，遵循 `docs/development-workflow.md` 中的 Research Gate。

设计本地扩展前，先检查 New API 原生后台的用户、token、分组、渠道、价格、支付、订阅、日志、设置和模型倍率。新增本地代码前，先把缺口记录到 `docs/new-api-code-map.md`。

首次收费 API relay 验证参考 `docs/phase1-new-api-validation-runbook.md`。

## 每日检查

- New API health endpoint 正常。
- PostgreSQL 和 Redis 容器健康。
- `bash ops/validate-ops-profile.sh config/ops-profiles/glm-standard.example.json` 确认预期 GLM standard-pool 配置。
- `bash ops/channel-health-advisor.sh config/ops-profiles/glm-standard-health.example.json` 在渠道变更或公开状态更新前没有严重失败。
- 设置 `NEW_API_TEST_TOKEN` 后，`bash ops/relay-diagnostics.sh` 对主测试模型通过。
- 渠道变更、模型新增或 New API 镜像升级前后，`bash ops/e2e-api-billing.sh` 通过。
- 风险操作前，`bash ops/export-config-snapshot.sh` 生成当前脱敏配置快照。
- 上游供应商余额高于告警阈值。
- 错误率和失败 relay 数没有持续上升。
- 最近数据库备份存在且可恢复。
- 最近 restic 离线备份可通过 `restic snapshots` 查询。
- Uptime Kuma 公开状态页只展示粗粒度状态，不暴露供应商、渠道 ID、余额或内部错误详情。

部署、DNS、Caddy 或 Cloudflare Tunnel 变更后，运行：

```bash
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

## 事故响应

遇到计费、支付或供应商故障时，先禁用受影响渠道或支付路径，导出相关日志，再核对用户余额。不要删除失败订单或用量日志；用管理员备注标记。

## Operations Profiles

渠道变更、模型新增、镜像升级或交接给其他操作者前运行：

```bash
bash ops/export-config-snapshot.sh
bash ops/validate-ops-profile.sh config/ops-profiles/glm-standard.example.json
bash ops/channel-health-advisor.sh config/ops-profiles/glm-standard-health.example.json
```

profile validator 是只读的。它检查 PostgreSQL 中的 channels 和 abilities，报告用户、token、订阅和支付相关配置。只有设置 `NEW_API_TEST_TOKEN` 时才调用 `/v1/models`。完整额度核账请单独运行 `NEW_API_TEST_MODEL=glm-5.1 bash ops/e2e-api-billing.sh`。

health advisor 也是只读的。它汇总启用渠道容量、禁用渠道、近期请求和错误样本、错误率、p95 use time、New API channel-test 时间和操作建议。

搭建期保持 profile `mode: development`。正式收费前复制 profile，切到 `mode: production` 并收紧 standard-pool 阈值。

## 公开状态页

用户侧状态页使用 Uptime Kuma。monitors 和低额度测试 token 保存在 Kuma UI/volume 中，不进入 git。参考 `docs/kuma-status-runbook.md`。

发布状态页时，在服务器设置 `STATUS_DOMAIN`，并把 `Caddyfile.status.example` 中的 status-domain block 合并到生产 Caddyfile。基础 `Caddyfile` 默认不公开 Kuma。

## CPA Adapter

CPA 是可选组件，必须放在 New API 后面。使用 `docker-compose.cpa.yml` 让它加入 New API 相同的 Docker 网络；只有需要通过 SSH 隧道访问管理 UI 时才额外使用 `docker-compose.cpa.ui.yml`。不要把 `8317` 暴露到公网。详见 `docs/zh-CN/cpa-runbook.md`。

如果生产环境启用了 Cloudflare Tunnel，CPA UI 命令必须带上当前正在使用的 `docker-compose.cloudflare-tunnel.yml` overlay 和固定 project name `-p lihan_ai`；否则 `--remove-orphans` 可能会移除 `relay-cloudflared`。请使用 `docs/zh-CN/cpa-runbook.md` 中的可复制命令。

## Live E2E

不打印 token secret 的真实 API 计费验证：

```bash
NEW_API_TEST_TOKEN_NAME=test_2505081251 NEW_API_TEST_MODEL=glm-5.1 bash ops/live-e2e-billing-from-db-token.sh
```

浏览器级验证：

```bash
npm run e2e:web:new-api
KUMA_BASE_URL=http://localhost:3011 npm run e2e:web:kuma
```

如果 New API 临时换了端口：

```bash
NEW_API_BASE_URL=http://localhost:3102 npm run e2e:web:new-api
```

Windows PowerShell 调用 WSL shell E2E 时，把变量放在 `bash` 命令内部：

```powershell
bash -lc 'NEW_API_BASE_URL=http://localhost:3102 ./ops/live-e2e-billing-from-db-token.sh test_2505081251'
```

## 生产迁移

迁移到另一台 origin 服务器前：

```bash
SOURCE_SSH=root@old TARGET_SSH=root@new DEPLOY_PATH=/opt/lihan_ai bash ops/migration-preflight.sh
```

最终维护窗口：

```bash
CONFIRM_FINAL_CUTOVER=yes SOURCE_SSH=root@old TARGET_SSH=root@new DEPLOY_PATH=/opt/lihan_ai bash ops/migrate-prod.sh
```

不要在目标服务器通过 `ops/verify-remote-prod.sh` 前更新 DNS 或 edge upstream。
