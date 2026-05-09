# 生产部署 Runbook

## 首次 Origin 初始化

使用一台 Linux origin 服务器运行 New API、PostgreSQL、Redis、Caddy 和 Uptime Kuma。

生产环境从 `main` 部署。部署 wrapper 会拒绝非 `main` 的生产部署，除非为了已记录的紧急情况显式设置 `ALLOW_NON_MAIN_PROD_DEPLOY=1`。

1. 将本仓库 clone 到 `/opt/lihan_ai`。
2. 复制 `.env.production.example` 为 `.env.production`。
3. 替换所有 `CHANGE_ME`，并设置 `DOMAIN` 和 `ACME_EMAIL`。
4. `.env.production` 只保留在服务器上；它被 git 忽略。
5. 运行：

```bash
bash ops/bootstrap-server.sh
ENV_FILE=.env.production bash ops/preflight.sh
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d
ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

## 从本地远程部署

通过 SSH 部署一个干净的 Git ref：

```bash
DEPLOY_HOST=root@x.x.x.x DEPLOY_PATH=/opt/lihan_ai DEPLOY_REF=main bash ops/deploy-prod.sh
```

远程仓库如果存在本地未提交改动，部署脚本会拒绝继续。替换容器前，如果已有数据库正在运行，脚本会先创建 PostgreSQL 备份。

## 验证

运行：

```bash
DEPLOY_HOST=root@x.x.x.x bash ops/verify-remote-prod.sh
```

如果需要真实计费探针，先在 New API 创建一个低额度命名测试 token，然后运行：

```bash
DEPLOY_HOST=root@x.x.x.x RUN_LIVE_E2E=1 NEW_API_TEST_TOKEN_NAME=test_token_name NEW_API_TEST_MODEL=glm-5.1 bash ops/verify-remote-prod.sh
```

## 回滚

重新部署一个已知可用的 Git ref：

```bash
DEPLOY_HOST=root@x.x.x.x DEPLOY_REF=<known-good-ref> bash ops/deploy-prod.sh
```

如果数据已经发生变化，先导出当前数据库用于审计，再恢复已知可用的 PostgreSQL dump。
