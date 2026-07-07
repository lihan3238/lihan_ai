# CPA Runbook

CPA 不是备份、主机健康或运维看板。它只负责上游 adapter 流量和自身管理 UI；runtime、backup、磁盘、容器和恢复检查使用 `ops/check-production-runtime.sh`、`ops/backup-cron.sh` 和恢复演练脚本。

CPA 指 `router-for-me/CLIProxyAPI`。在本仓库里，它是 New API 后面的可选内部适配层。

## 上游基准文件

上游项目作为 submodule 保存在仓库中，便于审计和升级对比：

- `vendor/cli-proxy-api/docker-compose.yml`
- `vendor/cli-proxy-api/config.example.yaml`

更新 pinned submodule：

```bash
bash ops/sync-cpa-upstream-assets.sh
git diff --submodule vendor/cli-proxy-api
bash tests/cpa-compose.test.sh
```

不要在生产环境直接运行官方 compose。官方示例默认发布多个宿主机端口。生产应使用本仓库的 CPA overlay。

如果官方示例发生变化，先审查 submodule diff；只有仓库 overlay 需要跟随运行时变化时，才更新 `docker-compose.cpa.yml`。不要把官方示例里的公网端口发布直接复制到生产配置。

仓库 overlay 的目的有两个：

- New API 必须能通过共享的 `relay-internal` Docker 网络解析并访问 CPA。
- CPA 管理入口和 provider 凭证不能作为公网服务暴露。

## 生产配置

真实 CPA 配置保存在 git 外：

```bash
mkdir -p /opt/lihan_ai_deploy/shared/data/cpa/public /opt/lihan_ai_deploy/shared/logs/cpa
cp vendor/cli-proxy-api/config.example.yaml /opt/lihan_ai_deploy/shared/data/cpa/config.yaml
chmod 700 /opt/lihan_ai_deploy/shared/data/cpa
chmod 600 /opt/lihan_ai_deploy/shared/data/cpa/config.yaml
nano /opt/lihan_ai_deploy/shared/data/cpa/config.yaml
```

`shared/data/` 和 `shared/logs/` 位于 release checkout 之外。这样 CPA runtime 文件会跨 release 发布和回滚保留，但不会把 provider keys、auth files 或 logs 提交进仓库。

最低生产规则：

- `remote-management.secret-key` 必须设置为强随机值。
- 除非有明确原因要让管理接口超出容器内 loopback，否则保持 `remote-management.allow-remote: false`。推荐的 UI 访问方式仍然是 SSH 隧道。
- CPA API key 必须足够强，并且和 New API 用户 token 分开管理。
- 容器内使用 `auth-dir: "/root/.cli-proxy-api"`。
- 不要把 `8317` 暴露到公网。
- 上游 provider key 只放在 `/opt/lihan_ai_deploy/shared/data/cpa/config.yaml`。

如果启用 `logging-to-file: true`，必须设置正数的 `logs-max-total-size-mb`，例如 `200`；`error-logs-max-files` 也要保持有上限，例如 `10`。

推荐 CPA 文件日志上限：

```yaml
logging-to-file: true
logs-max-total-size-mb: 200
error-logs-max-files: 10
```

`DEPLOY_INCLUDE_CPA=1` 时，`ops/preflight.sh` 会检查 CPA config；如果启用了文件日志但 `logs-max-total-size-mb` 缺失或为 `0`，部署会失败。`docker-compose.cpa.yml` 同时给 CPA 容器配置 Docker `json-file` 轮转：`max-size=20m`、`max-file=5`。

生成密钥：

```bash
openssl rand -hex 32
```

如果你已经把 CPA 配置放在旧 runtime 路径，可以迁移到仓库 runtime 目录：

```bash
mkdir -p /opt/lihan_ai_deploy/shared/data/cpa /opt/lihan_ai_deploy/shared/logs/cpa
cp -a /opt/lihan_ai_runtime/.cli-proxy-api/. /opt/lihan_ai_deploy/shared/data/cpa/
chmod 700 /opt/lihan_ai_deploy/shared/data/cpa
chmod 600 /opt/lihan_ai_deploy/shared/data/cpa/config.yaml
```

然后在 `.env.production` 设置：

```env
CPA_CONFIG_PATH=/opt/lihan_ai_deploy/shared/data/cpa/config.yaml
CPA_AUTH_PATH=/opt/lihan_ai_deploy/shared/data/cpa
CPA_PUBLIC_PATH=/opt/lihan_ai_deploy/shared/data/cpa/public
CPA_LOG_PATH=/opt/lihan_ai_deploy/shared/logs/cpa
```

legacy 直接 checkout 部署仍可使用旧的 `/opt/lihan_ai/data/cpa` 路径；release 部署应使用 `/opt/lihan_ai_deploy/shared/data/cpa`。

## 内网启动 CPA

把 CPA 启动在和 New API 相同的 Docker 网络里：

```bash
cd /opt/lihan_ai_deploy/current

ops/cpa-ui.sh close
```

如果是直连源站部署，上面的命令等价于下面的局部 compose 命令。Tunnel 部署会追加 `docker-compose.cloudflare-tunnel.yml`，但 CPA 局部命令不要传 `--scale caddy=0`；这个参数只用于全栈 release promote 或全栈 compose up。

```bash
docker compose -p lihan_ai --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  up -d --force-recreate --no-deps cli-proxy-api
```

New API 访问 CPA 的地址是：

```text
http://cli-proxy-api:8317
```

然后在 New API 后台创建兼容渠道，API key 使用 CPA 配置里的 `api-keys`。

推荐的 New API 渠道设置：

- Base URL：`http://cli-proxy-api:8317`
- API key：CPA `api-keys` 中的一个值
- Model names：和 CPA 中配置的 provider/model aliases 保持一致

不要让 New API 用公网 origin 域名访问 CPA。那会离开 Docker 内网，绕到 Caddy 或公网网络，排障也会更麻烦。

## CPA 上游出站代理

当 New API 把 CPA 作为上游适配层时，真正连接模型供应商的是 CPA：

```text
client -> New API -> cli-proxy-api -> upstream provider
```

这种拓扑下，住宅或 ISP 出站代理要配置在 CPA，不要配置在 New API 渠道里。New API 渠道保持：

- Base URL：`http://cli-proxy-api:8317`
- Proxy Address：留空

如果所有 CPA 上游流量都需要从同一个出口离开，在 `/opt/lihan_ai_deploy/shared/data/cpa/config.yaml` 设置顶层代理：

```yaml
proxy-url: "socks5://newapi:<password>@38.125.120.23:1080/"
```

如果只想让某个 provider 或 credential 走代理，顶层保持 `proxy-url: ""`，只在对应条目上设置 `proxy-url`。CPA 也支持在条目上写 `proxy-url: "direct"` 或 `proxy-url: "none"`，显式绕过全局代理和环境代理。

小型 GOST SOCKS5 出站 VPS 要保持私有：

- GOST 可以监听 `0.0.0.0:1080`，但防火墙只允许 origin 公网 IP 访问 `1080/tcp`。
- 启用默认拒绝入站防火墙前，必须先显式放行 SSH。
- GOST 使用独立 `gost` 系统用户运行，并执行 `systemctl enable --now gost`。
- 如果日志出现 `open /etc/gost/gost.yml: permission denied`，执行 `chown root:gost /etc/gost /etc/gost/gost.yml`、`chmod 750 /etc/gost`、`chmod 640 /etc/gost/gost.yml`。
- 代理密码一旦贴进 shell、聊天、工单或临时笔记，调通后立即轮换。

验证出站 VPS：

```bash
systemctl is-enabled gost
systemctl is-active gost
ss -lntp | grep ':1080'
ufw status verbose
curl -sS --connect-timeout 5 --max-time 20 \
  -x "socks5h://newapi:<password>@127.0.0.1:1080" \
  https://ifconfig.me
```

从 origin 验证：

```bash
curl -4 -sS --max-time 10 https://ifconfig.me
curl -sS --connect-timeout 5 --max-time 20 \
  -x "socks5h://newapi:<password>@38.125.120.23:1080" \
  https://ifconfig.me

grep -nE 'proxy-url:' /opt/lihan_ai_deploy/shared/data/cpa/config.yaml \
  | sed -E 's#(socks5h?://)[^@]+@#\1<redacted>@#g'

docker inspect -f '{{.Name}} restart={{.HostConfig.RestartPolicy.Name}} state={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
  relay-cpa relay-new-api relay-postgres relay-redis relay-cloudflared 2>/dev/null
```

修改 CPA 代理设置后，只重启 CPA：

```bash
cd /opt/lihan_ai_deploy/current
docker restart relay-cpa
docker logs --tail=80 relay-cpa
```

## 管理 UI

管理 UI 不公开到互联网。需要临时使用时，启动只绑定本机的 UI override：

```bash
cd /opt/lihan_ai_deploy/current

ops/cpa-ui.sh open
```

`ops/cpa-ui.sh open` 会追加 `docker-compose.cpa.ui.yml`，在启用 Cloudflare Tunnel 时保留 active Tunnel overlay，并使用 `--force-recreate --no-deps`，这样 CPA UI 局部操作只刷新 CPA，不会重建 `new-api`、`cloudflared` 或 `caddy`。基础 CPA compose 会把 `config.yaml` 只读挂载。UI override 会刻意把 `/CLIProxyAPI/config.yaml` 重新挂载为可写，这样管理 UI 才能保存配置。只有正在管理 CPA 配置时才使用这个 override。

从本机建立 SSH 隧道：

```bash
ssh -L 8317:127.0.0.1:8317 <deploy-user>@<origin-host>
```

浏览器打开：

```text
http://127.0.0.1:8317/management.html
```

安全模型：

- provider firewall 不开放入站 `8317`。
- Compose UI override 只把 `8317` 绑定到宿主机 `127.0.0.1`。
- SSH 把你本机浏览器转发到服务器 loopback listener。
- CPA management routes 仍然需要 `remote-management.secret-key`。

用完后，不带 UI override 重启 CPA，移除本机端口发布：

```bash
cd /opt/lihan_ai_deploy/current

ops/cpa-ui.sh close
```

这样 CPA 会回到正常运行时使用的只读 config mount。

使用 `ops/cpa-ui.sh ps` 确认容器状态和本机端口绑定。不要在临时 CPA UI 命令里使用 `--remove-orphans` 或 `--scale caddy=0`；这些参数属于全栈操作，不属于单服务 CPA UI 会话。

## 公开 CPA 额度快照

New API 公网主页只能读取去敏后的静态快照。不要把 `HomePageContent`、Caddy、Cloudflare Tunnel 或任何公网浏览器路径指向 CPA management routes、`8317` 或上游额度检查。

本仓库提供：

- `ops/cpa-quota-snapshot.sh`：把 CPA 原始额度 JSON 转成公开 allowlist 快照。
- `public/cpa-quota/home.html`：完整 New API 自定义主页。
- `public/cpa-quota/widget.html`：可复用的紧凑额度组件。
- `cpa-quota-static`：`docker-compose.cpa.yml` 里的内网静态服务；它没有宿主机 `ports:`，只加入 `relay-internal`。

主快照文件位置：

```text
${CPA_PUBLIC_PATH:-/opt/lihan_ai_deploy/shared/data/cpa/public}/quota-snapshot.json
```

为了向后兼容，默认发布脚本也会写：

```text
${CPA_PUBLIC_PATH:-/opt/lihan_ai_deploy/shared/data/cpa/public}/codex-quota.json
```

你在 CPA 管理 UI 手动刷新额度后，再从 origin 服务器发布新快照。快照会包含 `queried_at`；公网主页会显示成 `Last queried`，这样可以直接判断额度信息是否过期。

生产环境常规流程是在 origin 服务器上跑一个命令。这个脚本不会打开或关闭 CPA UI；你现有的 UI 会话保持原样。它会优先从 `${CPA_CONFIG_PATH:-/opt/lihan_ai_deploy/shared/data/cpa/config.yaml}` 读取 `remote-management.secret-key`，读不到时才隐藏输入提示。它会查询所有已启用且有已知额度 endpoint 的 credential，然后发布一份去敏快照：

```bash
cd /opt/lihan_ai_deploy/current

CPA_PUBLIC_PATH=/opt/lihan_ai_deploy/shared/data/cpa/public \
  bash ops/cpa-quota-refresh-all.sh
```

内置额度 endpoint 默认值：

- `codex`、`openai`、`chatgpt`：`https://chatgpt.com/backend-api/wham/usage`
- `claude`、`anthropic`：`https://api.anthropic.com/api/oauth/usage`

脚本会跳过 disabled、unavailable、缺少 `auth_index` 或 provider 暂不支持的 credential。如果某个 provider endpoint 之后变了，可以在单次运行时覆盖，例如：

```bash
CPA_QUOTA_URL_CLAUDE="https://api.anthropic.com/api/oauth/usage" \
CPA_PUBLIC_PATH=/opt/lihan_ai_deploy/shared/data/cpa/public \
  bash ops/cpa-quota-refresh-all.sh
```

最直接的流程是让 CPA 通过受保护的 management API 调上游额度接口，然后把返回结果直接管道给去敏脚本。这个方式不改 CPA 镜像，也不会把 management routes 暴露到公网：

```bash
cd /opt/lihan_ai_deploy/current

read -s CPA_MGMT_KEY
AUTH_INDEX="<auth_index from /v0/management/auth-files>"
QUOTA_URL="https://chatgpt.com/backend-api/wham/usage"
LABEL="Codex pool"

curl -fsS -X POST http://127.0.0.1:8317/v0/management/api-call \
  -H "Authorization: Bearer $CPA_MGMT_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -nc --arg auth "$AUTH_INDEX" --arg url "$QUOTA_URL" '{
    auth_index: $auth,
    method: "GET",
    url: $url,
    header: {
      "Authorization": "Bearer $TOKEN$"
    }
  }')" \
| CPA_PUBLIC_PATH=/opt/lihan_ai_deploy/shared/data/cpa/public \
  bash ops/cpa-quota-snapshot.sh --label "$LABEL"
```

换成其他 GPT/OpenAI、Claude、Gemini 或其他 CPA-backed credential 时，模式不变，只调整 `AUTH_INDEX`、`QUOTA_URL`、请求 headers 和 `LABEL`。去敏脚本能识别 CPA `api-call` 的 `{status_code, header, body}` 外壳，只会解析并发布其中的 JSON `body`。

如果已经把原始额度 JSON 存成临时文件：

```bash
cd /opt/lihan_ai_deploy/current

CPA_PUBLIC_PATH=/opt/lihan_ai_deploy/shared/data/cpa/public \
  bash ops/cpa-quota-snapshot.sh \
    --input /tmp/cpa-codex-quota.json \
    --label "Codex pool"
```

脚本只写入 provider title、account label、`plan_type`、状态、额度窗口名、使用百分比、limit、remaining count 和 reset time 等 allowlist 字段。它支持 GPT/OpenAI、Claude、Codex、Antigravity、Gemini 等 CPA-backed providers 的通用 `providers[].accounts[].windows[]` 快照。它不会把 email、account ID、API key、access token、refresh token、cookie 或原始 provider payload 复制进公开快照。

CPA 文件日志和 Docker logs 可以帮助审计是否发生过刷新或上游 API call，但它们不是安全的公开快照来源。管理 UI 的额度检查会通过 `/v0/management/api-call` 等受保护 management routes 执行；CPA request logging 明确跳过 `/v0/management` 和 `/management` 路径，而完整 request log 又可能包含敏感上游 payload。以后如果要做 `/management.html#/quota` 一键同步，应做成受保护的 CPA publisher/backend hook，写同一份去敏 `quota-snapshot.json`，不要抓日志，也不要暴露 management routes。

直连源站 Caddy 部署会提供：

```text
https://<DOMAIN>/cpa-quota/home.html
https://<DOMAIN>/cpa-quota/widget.html
https://<DOMAIN>/cpa-quota/data/quota-snapshot.json
https://<DOMAIN>/cpa-quota/data/codex-quota.json
```

Cloudflare Tunnel 部署继续保持 `caddy=0`，但要在 `/opt/lihan_ai_deploy/shared/cloudflared/config.yml` 里把这个 path 放到 New API catch-all 前面，并指向内网静态服务：

```yaml
ingress:
  - path: /cpa-quota/*
    service: http://cpa-quota-static:8080
  - hostname: origin.lihan3238.top
    service: http://new-api:3000
  - service: http://new-api:3000
```

然后通过正常 compose overlay 或下一次 release promote 重建 `cloudflared` 和静态服务。

New API 的 `HomePageContent` 填完整 homepage URL。不要把 iframe 或 Markdown wrapper 粘进 `HomePageContent`；New API 的 Markdown render path 可能 sandbox scripts，导致额度面板失效。

```text
https://api.lihan3238.com/cpa-quota/home.html
```

之后公网用户刷新 New API 首页时，只会读取静态文件。只有你手动刷新 CPA 额度状态并重新运行 `ops/cpa-quota-snapshot.sh` 后，主页显示的额度才会更新。

## 从 New API 验证

在 origin 服务器上执行：

```bash
docker exec relay-new-api wget -q -O - http://cli-proxy-api:8317/v1/models \
  --header="Authorization: Bearer <CPA_API_KEY>"
```

如果失败，检查 `docker logs relay-cpa`、CPA 配置路径，以及容器是否加入 `relay-internal`。

如果之前用临时 `docker run -p 8317:8317` 启动过 CPA，先停止旧容器再启用 Compose：

```bash
docker ps --format '{{.Names}} {{.Ports}}' | grep 8317
docker rm -f <old-cpa-container>
```

然后通过 `docker-compose.cpa.yml` 启动 CPA，让 New API 和 CPA 共享服务发现。
