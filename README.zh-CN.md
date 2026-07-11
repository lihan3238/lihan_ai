# lihan_ai

这是一个精简的生产部署封装，只管理上游 New API 和上游 CLIProxyAPI。

当前仓库不再走本地 fork、本地前端构建、Caddy、Playwright、Spec Kit 或
vendor submodule。正常路径只保留 Docker Compose、环境模板、备份脚本和运维
文档，方便交给 Komodo 观察、更新、备份和迁移。

## 运行组件

- `new-api`：上游 `calciumion/new-api`，在 env 示例中固定 tag 与 digest
- `cli-proxy-api`：上游 `eceasy/cli-proxy-api`，在 env 示例中固定 tag 与 digest
- `postgres`: `postgres:15-alpine`
- `redis`: `redis:7-alpine`
- `cloudflared`：上游 `cloudflare/cloudflared`，固定 tag 与 digest，并作为单独 ingress stack

## 文件结构

```text
docker-compose.yml                    # New API + PostgreSQL + Redis
docker-compose.prod.yml               # 生产日志配置
docker-compose.cpa.yml                # CLIProxyAPI
docker-compose.cpa.ui.yml             # 临时打开 CPA 可写管理 UI
docker-compose.cloudflare-tunnel.yml  # 独立 Cloudflare Tunnel stack
.env.production.example               # 生产环境变量模板
ops/                                  # 简明运维命令
docs/                                 # 简明运维文档
```

## 部署

在目标机器上准备真实环境变量：

```bash
cp .env.production.example .env.production
```

启动核心服务和 CPA：

```bash
ENV_FILE=.env.production WITH_CPA=1 ops/compose.sh up -d
```

Cloudflared 建议在 Komodo 里作为单独 Stack 导入：

```bash
ENV_FILE=.env.production docker compose -p hostinger-cloudflared \
  -f docker-compose.cloudflare-tunnel.yml up -d
```

## 更新

常规更新交给 Komodo。推荐手动流程：

```text
PullStack lihan_ai services=[new-api, cli-proxy-api]
DeployStack lihan_ai services=[new-api, cli-proxy-api]
Run lihan-ai-status-readonly
```

不要把 PostgreSQL、Redis、cloudflared 和 app 容器混在一起自动更新。
