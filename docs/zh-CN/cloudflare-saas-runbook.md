# Cloudflare SaaS Tunnel Runbook

本文用于把公开 API 入口切到 `https://api.lihan3238.com`，并通过 Cloudflare for SaaS + Cloudflare Tunnel 回源。

流量路径：

```text
用户 -> api.lihan3238.com 优选 Cloudflare IP -> Cloudflare Custom Hostname
  -> fallback origin origin.lihan3238.top -> Cloudflare Tunnel
  -> Hostinger 上的 cloudflared -> new-api:3000
```

Tunnel 模式下，公网 `80/443` 由 Cloudflare 边缘节点监听，不再由 Hostinger 源站监听。源站只需要 `cloudflared` 主动连出到 Cloudflare。Caddy 仍保留在仓库里作为旧直连回源的回退路径，但正常 Tunnel 发布会把 Caddy 缩容为 0。

## Cloudflare Zone

在 Cloudflare 添加 `lihan3238.top`，并在 Spaceship 把该域名 nameservers 改成 Cloudflare 给出的两个 nameservers。等待 Cloudflare 显示 zone 已 Active。

在 Cloudflare Zero Trust 创建 named Tunnel，例如 `lihan-ai-prod`。也可以用命令创建：

```bash
cloudflared tunnel login
cloudflared tunnel create lihan-ai-prod
cloudflared tunnel route dns lihan-ai-prod origin.lihan3238.top
```

这会把 fallback origin 路由到 Tunnel：

```text
origin.lihan3238.top -> <tunnel-uuid>.cfargotunnel.com
```

Tunnel 路由生效后，删除旧的 `origin.lihan3238.top A <origin-ip>` 记录。fallback origin 应该指向 Cloudflare Tunnel，不再直接指向源站服务器 IP。

在 `SSL/TLS -> Custom Hostnames` 中保持 Cloudflare for SaaS 开启，并保持 fallback origin：

```text
origin.lihan3238.top
```

## Custom Hostname

添加或保留 custom hostname：

```text
api.lihan3238.com
```

TLS 保持默认，证书机构用 Let's Encrypt。Cloudflare 会给出 DNS 验证 TXT 记录，把它们添加到 Spaceship 的 `lihan3238.com` DNS 中，等待 hostname 和 certificate 状态都变成 `Active`。

验证完成后，`lihan3238.com` 继续留在 Spaceship DNS，公开入口继续指向你的优选 Cloudflare IP：

```text
Type: A
Host: api
Value: 172.64.155.231
```

Tunnel 路径下不要把 `api.lihan3238.com` 指向源站服务器 IP。

## 源站文件

在 Hostinger 源站创建共享 runtime 目录：

```bash
sudo mkdir -p /opt/lihan_ai_deploy/shared/cloudflared
sudo chown -R lihan:lihan /opt/lihan_ai_deploy/shared/cloudflared
chmod 700 /opt/lihan_ai_deploy/shared/cloudflared
```

把 `cloudflared tunnel create` 生成的 tunnel credentials JSON 放到：

```text
/opt/lihan_ai_deploy/shared/cloudflared/tunnel.json
```

创建：

```text
/opt/lihan_ai_deploy/shared/cloudflared/config.yml
```

示例：

```yaml
tunnel: <tunnel-uuid>
credentials-file: /etc/cloudflared/tunnel.json

ingress:
  - hostname: origin.lihan3238.top
    service: http://new-api:3000
  - service: http://new-api:3000
```

最后一条 catch-all ingress 是有意保留的。Cloudflare for SaaS 可能用 `origin.lihan3238.top` 做 fallback 路由，同时把 `Host: api.lihan3238.com` 保留下来；未匹配 hostname 的请求也应该进入 New API。

锁定权限：

```bash
chmod 644 /opt/lihan_ai_deploy/shared/cloudflared/tunnel.json
chmod 644 /opt/lihan_ai_deploy/shared/cloudflared/config.yml
```

运行中的 `cloudflare/cloudflared` 容器默认不是 root，因此 bind-mounted `config.yml` 和 `tunnel.json` 必须能被容器用户读取。原始 `<tunnel-uuid>.json` 和 `cert.pem` 不要进 git；不作为 runtime bind mount 时，可以用更严格的权限保存。

启动 stack 前确认这两个 bind mount 源路径都是普通文件。只要路径不存在，Docker 可能会自动创建同名目录，随后 `cloudflared` 会因为 `read /etc/cloudflared/config.yml: is a directory` 反复重启。

```bash
test -f /opt/lihan_ai_deploy/shared/cloudflared/config.yml && echo "config.yml is file"
test -f /opt/lihan_ai_deploy/shared/cloudflared/tunnel.json && echo "tunnel.json is file"
```

如果 `config.yml` 已经被误创建成目录，只删除这个错误目录，然后用 tunnel UUID 和 credentials JSON 重新创建配置文件：

```bash
sudo find /opt/lihan_ai_deploy/shared/cloudflared -maxdepth 3 -ls
sudo rm -rf /opt/lihan_ai_deploy/shared/cloudflared/config.yml
sudoedit /opt/lihan_ai_deploy/shared/cloudflared/config.yml
chmod 644 /opt/lihan_ai_deploy/shared/cloudflared/config.yml
```

如果 `tunnel.json` 丢失，需要找回或重新创建 Cloudflare 生成的 tunnel credentials。这个文件包含 Cloudflare Tunnel 凭据，不能手写伪造（cannot be hand-written）。

## 生产 Env

编辑共享 env：

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
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1
CLOUDFLARE_SAAS_FALLBACK_ORIGIN=origin.lihan3238.top
CLOUDFLARED_CONFIG_PATH=/opt/lihan_ai_deploy/shared/cloudflared/config.yml
CLOUDFLARED_CREDENTIALS_PATH=/opt/lihan_ai_deploy/shared/cloudflared/tunnel.json
```

不要设置：

```env
DOMAIN=origin.lihan3238.top
```

`CLOUDFLARE_SAAS_ORIGIN_IP` 只用于旧直连源站 SNI 检查。Tunnel 模式下保持为空即可。

## 部署

从本地仓库执行 prepare、smoke、promote：

正常 release 路径现在会从远端 `.env.production` 读取 `DEPLOY_INCLUDE_CPA=1` 和 `DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1`。下面保留显式变量作为应急覆盖示例；日常发布可以使用 README 里的短命令。

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> \
DEPLOY_REF=main \
DEPLOY_INCLUDE_CPA=1 \
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1 \
bash ops/deploy-release.sh prepare

DEPLOY_HOST=<deploy-user>@<origin-host> \
DEPLOY_INCLUDE_CPA=1 \
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1 \
bash ops/deploy-release.sh smoke

DEPLOY_HOST=<deploy-user>@<origin-host> \
DEPLOY_INCLUDE_CPA=1 \
DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=1 \
bash ops/deploy-release.sh promote
```

`prepare` 会把准备好的 release 记录为 `candidate`，所以正常 `smoke` 和 `promote` 不需要手动填 `RELEASE_ID`。只有明确要操作某个旧 release 时，才传 `RELEASE_ID=<release-id>`。

源站手动重启等价命令：

```bash
cd /opt/lihan_ai_deploy/current

docker compose -p lihan_ai --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  -f docker-compose.cloudflare-tunnel.yml \
  up -d --remove-orphans --scale caddy=0
```

进入 New API 后台，把公开站点地址、Base URL 或同类配置改成：

```text
https://api.lihan3238.com
```

## Cloudflare 规则

对 `api.lihan3238.com/*` 设置 Cache Bypass。不要对 `/api/*` 或 `/v1/*` 使用 JS Challenge、Bot Fight Mode 或交互式挑战。切换后重点观察流式 API 客户端是否出现超时或断流。

## 验证

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
  -f docker-compose.cloudflare-tunnel.yml \
  ps
```

验收项：

- `relay-cloudflared` 正在运行。
- `relay-caddy` 不存在，或没有发布 `80/443`。
- `https://api.lihan3238.com` 能打开 New API UI。
- 登录和后台页面正常。
- `/api/status` 返回 `success: true`。
- 测试 token 可以请求 `/v1/models`。
- 使用 CPA 的 New API 渠道仍指向 Docker 内网 CPA 服务，不要改成公网域名。

## 回滚

如果 Tunnel 路径失败，保持 Hostinger stack 运行，临时把 SaaS fallback origin 切回已知可用的直连回源路径，或恢复上一份 env 备份并回滚 release：

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> \
DEPLOY_INCLUDE_CPA=1 \
bash ops/deploy-release.sh rollback
```

如果要手动回到旧 Caddy 路径，设置 `DEPLOY_INCLUDE_CLOUDFLARE_TUNNEL=0`，恢复 `CLOUDFLARE_SAAS_ORIGIN_IP=<origin-ip>`，并用基础生产 compose 重建 Caddy。这个路径只作为临时恢复手段，因为它会重新引入源站证书问题。
