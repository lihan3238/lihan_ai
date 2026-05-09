# 迁移 Runbook

## 定义

本项目 V1 迁移目标是短维护窗口内不丢数据。它不是零停机迁移。

## 预检

先在目标服务器准备相同仓库路径和 `.env.production`，然后运行：

```bash
SOURCE_SSH=root@old TARGET_SSH=root@new DEPLOY_PATH=/opt/lihan_ai bash ops/migration-preflight.sh
```

预检会检查源服务器和目标服务器，创建源库备份，通过本机中转复制备份，并在目标服务器上执行隔离恢复演练。

## 最终切换

只在维护窗口执行：

```bash
CONFIRM_FINAL_CUTOVER=yes SOURCE_SSH=root@old TARGET_SSH=root@new DEPLOY_PATH=/opt/lihan_ai bash ops/migrate-prod.sh
```

脚本会停止源服务器的 `caddy` 和 `new-api`，创建最终 PostgreSQL dump，将备份复制到目标服务器，恢复目标数据库，启动目标生产栈，并验证 `/api/status`。

## DNS 或 Edge 切换

目标服务器验证通过后，再更新其中之一：

- `api.example.com` 的 DNS A 记录。
- 如果已经使用 edge proxy，则更新 edge 的 `ORIGIN_UPSTREAM`。

在新服务器用户流量和计费日志确认前，保持旧服务器不变。

## 回滚

DNS 或 edge 切换前，可以在源服务器重启服务：

```bash
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d caddy new-api
```

DNS 或 edge 切换后，如果旧 origin 还没有接受新的写入，可以把流量重新指回旧 origin。若两个 origin 都已经接受写入，先停止操作并手工核对日志，不要直接覆盖恢复。
