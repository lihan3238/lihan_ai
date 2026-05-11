# 运维 Runbook

## 当前运维模型

生产运维面刻意保持很小：

- New API
- PostgreSQL
- Redis
- 直连源站模式下的 Caddy，或 Tunnel 模式下的 Cloudflare Tunnel
- 可选内部 CPA
- 本地 PostgreSQL 备份、校验、恢复、恢复演练和迁移脚本

仓库不再运行独立监控栈。应用层可见性使用 New API 自带后台；部署验收和人工检查使用 wrapper 脚本。

## 每日快速检查

在生产服务器上：

```bash
cd /opt/lihan_ai_deploy/current
docker compose -p lihan_ai --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  -f docker-compose.cloudflare-tunnel.yml \
  ps

COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh
curl -i https://api.lihan3238.com/api/status
```

如果 CPA 或 Cloudflare Tunnel 未启用，去掉对应 compose overlay。

## Env 样板对齐

生产 env 位置：

```text
/opt/lihan_ai_deploy/shared/.env.production
```

Release `prepare` 会在 preflight 前自动调用 `ops/sync-env-template.sh`。也可以在 release checkout 手动执行：

```bash
cd /opt/lihan_ai_deploy/current
bash ops/sync-env-template.sh /opt/lihan_ai_deploy/shared/.env.production .env.production.example
```

规则：

- 先创建 `.bak.<UTC>` 备份。
- 将 `.env.production.example` 中存在但生产 env 缺失的 key 追加进去。
- 永不覆盖已有值。
- 废弃 key 只报告，不删除。
- `ops/preflight.sh` 仍负责拦截 `CHANGE_ME` 占位值。

## 备份

手动备份：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-postgres.sh
```

定时备份：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/backup-cron.sh
```

建议 crontab：

```cron
15 3 * * * cd /opt/lihan_ai_deploy/current && ENV_FILE=.env.production bash ops/backup-cron.sh
```

手动下载：

```bash
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump .
scp <deploy-user>@<origin-host>:/opt/lihan_ai_deploy/shared/backups/postgres/<dump>.dump.sha256 .
```

恢复演练：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<dump>.dump
```

## New API 分组

只保留：

- `default`：普通朋友/用户。
- `vip`：人工授予的高优先级或优惠用户。

旧 `standard` 分组不再属于当前运维模型。仓库不会自动改生产数据库；请在 New API 后台手动把用户、token、渠道能力、模型权限和价格从 `standard` 迁到 `default`，只给明确需要的人授予 `vip`。

只读验收：

```bash
bash ops/validate-ops-profile.sh config/ops-profiles/glm-default.example.json
bash ops/channel-health-advisor.sh config/ops-profiles/glm-default-health.example.json
```

## CPA

CPA 只保持内部访问。不要公开 `8317`。

临时 UI 会话：

```bash
cd /opt/lihan_ai_deploy/current
ops/cpa-ui.sh open
ops/cpa-ui.sh ps
```

本地隧道：

```bash
ssh -L 8317:127.0.0.1:8317 <deploy-user>@<origin-host>
```

用完关闭：

```bash
ops/cpa-ui.sh close
```

New API 渠道应指向 Docker 内部 CPA 地址，不要改成公网域名。

## 部署验收

每次生产 promote 后：

```bash
cd /opt/lihan_ai_deploy/current
readlink -f /opt/lihan_ai_deploy/current
COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh
curl -i https://api.lihan3238.com/api/status
ENV_FILE=.env.production bash ops/backup-cron.sh
```

然后在 New API 验证：

- 公网域名首页能打开。
- 管理后台能登录。
- `/api/status` 返回 success。
- 测试 token 能调用 `/v1/models`。
- 如果启用 CPA，渠道仍使用 Docker 内部地址。

## 清理安全线

归档 `/opt/lihan_ai` 或 `/opt/lihan_ai_runtime` 等旧目录前：

- `readlink -f /opt/lihan_ai_deploy/current` 指向预期 release。
- 运行时检查通过。
- 备份和恢复演练通过。
- `docker inspect relay-cpa` 不再显示旧 runtime 目录挂载。
- crontab 不再引用旧路径。

先改名归档，稳定后再删：

```bash
sudo mv /opt/lihan_ai /opt/lihan_ai.legacy-$(date +%Y%m%d)
sudo mv /opt/lihan_ai_runtime /opt/lihan_ai_runtime.legacy-$(date +%Y%m%d)
```

不要删除 `/opt/containerd`，也不要把 `docker compose down -v` 当清理命令。
