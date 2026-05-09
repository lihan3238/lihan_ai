# Edge 反向代理 Runbook

## 目的

使用一台中国优化线路 edge VPS 作为无状态 HTTPS 反向代理。edge 只改善用户访问链路，不保存 PostgreSQL、Redis、New API 配置、上游 API key 或计费状态。

## 初始化

在 edge 服务器上执行：

```bash
git clone <repo-url> /opt/lihan_ai
cd /opt/lihan_ai
cat > .env.edge <<'ENV'
EDGE_DOMAIN=api.example.com
ORIGIN_UPSTREAM=https://origin.example.com
ACME_EMAIL=ops@example.com
ENV
docker compose --env-file .env.edge -f docker-compose.edge.yml up -d
```

将 `EDGE_DOMAIN` 的 DNS 指向 edge IP。origin 域名应单独保留，供 edge 反代访问。

## 检查

```bash
docker compose --env-file .env.edge -f docker-compose.edge.yml config
docker compose --env-file .env.edge -f docker-compose.edge.yml ps
curl -I https://api.example.com/api/status
```

如果流式响应变慢，先比较直连 origin 和经过 edge 的耗时，再调整 New API 或 CPA 配置。

## 安全规则

- 不要把 `.env.production` 复制到 edge。
- 不要在 edge 上运行 PostgreSQL、Redis 或 New API，除非你明确要把它提升为 origin。
- Uptime Kuma 的公开状态页只展示粗粒度服务状态，不暴露渠道名、余额或上游细节。
