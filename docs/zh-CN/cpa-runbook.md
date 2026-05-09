# CPA Runbook

CPA 指 `router-for-me/CLIProxyAPI`。在本仓库里，它是 New API 后面的可选内部适配层。

## 上游基准文件

官方示例文件保存在仓库中，便于审计和升级对比：

- `vendor/cli-proxy-api/docker-compose.upstream.yml`
- `vendor/cli-proxy-api/config.example.yaml`

刷新命令：

```bash
bash ops/sync-cpa-upstream-assets.sh
```

不要在生产环境直接运行官方 compose。官方示例默认发布多个宿主机端口。生产应使用本仓库的 CPA overlay。

## 生产配置

真实 CPA 配置保存在 git 外：

```bash
sudo mkdir -p /opt/lihan_ai_runtime/.cli-proxy-api
sudo cp vendor/cli-proxy-api/config.example.yaml /opt/lihan_ai_runtime/.cli-proxy-api/config.yaml
sudo nano /opt/lihan_ai_runtime/.cli-proxy-api/config.yaml
```

最低生产规则：

- `remote-management.secret-key` 必须设置为强随机值。
- CPA API key 必须足够强，并且和 New API 用户 token 分开管理。
- 容器内使用 `auth-dir: "/root/.cli-proxy-api"`。
- 不要把 `8317` 暴露到公网。
- 上游 provider key 只放在 `/opt/lihan_ai_runtime/.cli-proxy-api/config.yaml`。

生成密钥：

```bash
openssl rand -hex 32
```

## 内网启动 CPA

把 CPA 启动在和 New API 相同的 Docker 网络里：

```bash
docker compose --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  up -d
```

New API 访问 CPA 的地址是：

```text
http://cli-proxy-api:8317
```

然后在 New API 后台创建兼容渠道，API key 使用 CPA 配置里的 `api-keys`。

## 管理 UI

管理 UI 不公开到互联网。需要临时使用时，启动只绑定本机的 UI override：

```bash
docker compose --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  -f docker-compose.cpa.ui.yml \
  up -d cli-proxy-api
```

从本机建立 SSH 隧道：

```bash
ssh -L 8317:127.0.0.1:8317 <deploy-user>@<origin-host>
```

浏览器打开：

```text
http://127.0.0.1:8317/management.html
```

用完后，不带 UI override 重启 CPA，移除本机端口发布：

```bash
docker compose --env-file .env.production \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f docker-compose.cpa.yml \
  up -d --remove-orphans cli-proxy-api
```

## 从 New API 验证

在 origin 服务器上执行：

```bash
docker exec relay-new-api wget -q -O - http://cli-proxy-api:8317/v1/models \
  --header="Authorization: Bearer <CPA_API_KEY>"
```

如果失败，检查 `docker logs relay-cpa`、CPA 配置路径，以及容器是否加入 `relay-internal`。
