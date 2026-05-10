# Cloudflare SaaS 域名 Runbook

本文用于把公开 API 入口切到 `https://api.lihan3238.com`，流量通过 Cloudflare for SaaS 进入 Hostinger 生产 origin。

流量路径：

```text
用户 -> api.lihan3238.com 优选 Cloudflare IP -> Cloudflare Custom Hostname
  -> fallback origin origin.lihan3238.top -> Hostinger Caddy -> new-api:3000
```

生产 origin 的 Caddy 必须服务真正公开的 custom hostname：`api.lihan3238.com`。不要把生产 `DOMAIN` 设置成 `origin.lihan3238.top`；这个域名只是 Cloudflare 找到源站的路线。

## Cloudflare Zone

在 Cloudflare 添加 `lihan3238.top`，并在 Spaceship 把该域名的 nameservers 改成 Cloudflare 给出的两个 nameservers。等待 Cloudflare 显示 zone 已 Active。

在 `lihan3238.top` 的 Cloudflare DNS 页面添加：

```text
Type: A
Name: origin
IPv4: 72.60.124.21
Proxy status: Proxied
```

在 `SSL/TLS -> Custom Hostnames` 开启 Cloudflare for SaaS，并设置 fallback origin：

```text
origin.lihan3238.top
```

源站证书验证期间，Cloudflare SSL 模式先用 `Full`。直连源站 SNI 验证通过后，再切到 `Full (strict)`。

## Custom Hostname

添加 custom hostname：

```text
api.lihan3238.com
```

TLS 保持默认，证书机构选择 Let's Encrypt。Cloudflare 会给出 DNS 验证记录。到 Spaceship 的 `lihan3238.com` DNS 页面添加两条 TXT 记录，然后等待 hostname 和 certificate 状态都变成 `Active`。

验证完成后，`lihan3238.com` 继续保留在 Spaceship DNS，并添加公开入口：

```text
Type: A
Host: api
Value: <CloudflareSpeedTest 测出的优选 Cloudflare IP>
```

可以添加多个 A 记录，放入测速最快的几个 Cloudflare IP。如果优选 IP 导致验证卡住，临时切到 Cloudflare 官方 CNAME 验证路径，等状态 Active 后再切回优选 A 记录。

## 源站配置

在 Hostinger origin 上执行：

```bash
cd /opt/lihan_ai_deploy/current

cp /opt/lihan_ai_deploy/shared/.env.production \
  /opt/lihan_ai_deploy/shared/.env.production.bak.$(date -u +%Y%m%dT%H%M%SZ)

nano /opt/lihan_ai_deploy/shared/.env.production
```

设置：

```env
DOMAIN=api.lihan3238.com
ACME_EMAIL=<your-email>
DEPLOY_INCLUDE_CPA=1
CLOUDFLARE_SAAS_FALLBACK_ORIGIN=origin.lihan3238.top
CLOUDFLARE_SAAS_ORIGIN_IP=72.60.124.21
```

不要设置：

```env
DOMAIN=origin.lihan3238.top
```

渲染配置并重建 Caddy：

```bash
cd /opt/lihan_ai_deploy/current

ENV_FILE=.env.production bash ops/preflight.sh

compose_files="-f docker-compose.yml -f docker-compose.prod.yml"
if grep -q '^DEPLOY_INCLUDE_CPA=1' .env.production; then
  compose_files="$compose_files -f docker-compose.cpa.yml"
fi

docker compose -p lihan_ai --env-file .env.production $compose_files config >/dev/null
docker compose -p lihan_ai --env-file .env.production $compose_files up -d --force-recreate caddy
docker logs --tail=120 relay-caddy
```

进入 New API 后台，把公开站点地址、Base URL 或同类配置改成：

```text
https://api.lihan3238.com
```

## Cloudflare 规则

对 `api.lihan3238.com/*` 设置 Cache Bypass。不要对 `/api/*` 或 `/v1/*` 使用 JS Challenge、Bot Fight Mode 或交互式挑战。切换后重点观察流式 API 客户端是否出现超时或断流。

## 验证

直连源站 SNI 和 Host 验证：

```bash
curl -vk --resolve api.lihan3238.com:443:72.60.124.21 \
  https://api.lihan3238.com/api/status
```

Cloudflare 公网验证：

```bash
curl -i https://api.lihan3238.com/api/status
```

仓库运行时检查：

```bash
cd /opt/lihan_ai_deploy/current
COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

Docker 状态：

```bash
docker compose -p lihan_ai --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  ps
```

验收项：

- `https://api.lihan3238.com` 能打开 New API UI。
- 登录和后台页面正常。
- `/api/status` 返回 `success: true`。
- 测试 token 可以请求 `/v1/models`。
- 使用 CPA 的 New API 渠道仍指向 Docker 内网 CPA 服务，不要改成公网域名。

## 回滚

如果 custom hostname 路径失败，保持 Hostinger stack 运行，并把 `api.lihan3238.com` DNS 指回之前已知可用的目标。如果是 `.env.production` 变更导致问题，恢复时间戳备份并重建 Caddy：

```bash
cp /opt/lihan_ai_deploy/shared/.env.production.bak.<timestamp> \
  /opt/lihan_ai_deploy/shared/.env.production

cd /opt/lihan_ai_deploy/current
docker compose -p lihan_ai --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  up -d --force-recreate caddy
```
