# lihan_ai

这是一个精简的生产部署封装，只管理上游 New API（模型接口聚合服务，其中 API 指
Application Programming Interface，即应用程序编程接口）和上游
CLIProxyAPI（命令行模型接口代理，其中 CLI 指 Command-Line Interface，即命令行界面）。

当前仓库不包含本地上游源码、前端构建、Caddy（网页入口与加密传输服务）、
Playwright（浏览器自动化测试框架）、Spec Kit（规范驱动开发工具包）或 `vendor`
子模块。正常路径只保留 Docker Compose（多容器声明式运行工具）、环境变量模板、
备份脚本和简明运维文档，由目标主机直接运行。

## 运行组件

- `new-api`：上游 `calciumion/new-api`；
- `cli-proxy-api`：上游 `eceasy/cli-proxy-api`；
- `postgres`：PostgreSQL（关系型数据库）15；
- `redis`：Redis（内存数据存储服务）7；
- `cloudflared`：Cloudflare Tunnel（Cloudflare 出站隧道服务）的隧道客户端，作为独立
  Compose 项目运行。

## 文件结构

```text
docker-compose.yml                    # New API + PostgreSQL + Redis
docker-compose.prod.yml               # 生产日志配置
docker-compose.cpa.yml                # CLIProxyAPI
docker-compose.cloudflare-tunnel.yml  # 独立 Cloudflare Tunnel Compose 项目
.env.production.example               # 生产环境变量模板
ops/                                  # 主机原生运维命令
docs/                                 # 简明运维文档
```

## 部署

在目标主机准备真实环境变量；真实值只保留在主机，不进入版本库：

```bash
cp .env.production.example .env.production
```

启动核心服务和 CPA（CLI Proxy API，命令行模型接口代理）：

```bash
ENV_FILE=.env.production WITH_CPA=1 ops/compose.sh up -d
```

主机维护通过公网 SSH（Secure Shell，安全远程登录协议）入口执行：

```bash
ssh hostinger-arch
```

CPA 管理端口固定绑定本机回环地址 `127.0.0.1:8317`。需要管理时运行专用转发别名：

```bash
ssh hostinger-cpa
```

命令会在认证后转入后台，然后访问 `http://127.0.0.1:18317/management.html`。
SSH 别名、本地端口转发及代理选择由 `~/.ssh/config` 负责，本仓库不保存实际主机地址、
代理地址、密钥或凭据。

CPA 请求正文审计属于宿主机本地策略，真实配置不会提交到版本库。所需开关和
10 GiB（gibibyte，二进制吉字节）热日志上限见 `docs/operations-runbook.md`。

Cloudflare Tunnel 单独启动，不与核心服务合并为同一 Compose 项目：

```bash
docker compose --env-file .env.production -p hostinger-cloudflared \
  -f docker-compose.cloudflare-tunnel.yml up -d
```

## 更新

应用更新由主机原生 Compose 执行，并限定到无状态应用容器：

```bash
ENV_FILE=.env.production WITH_CPA=1 ops/compose.sh pull new-api cli-proxy-api
ENV_FILE=.env.production WITH_CPA=1 \
  ops/compose.sh up -d --no-deps new-api cli-proxy-api
ENV_FILE=.env.production ops/check-runtime.sh
```

不要把 PostgreSQL、Redis、`cloudflared` 和应用容器混在一次自动更新中。
