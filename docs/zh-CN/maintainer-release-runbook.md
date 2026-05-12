# 维护者正式发布手册

这份手册是正式版后的稳定运营路径。GitHub Actions 只做无密钥验证，生产发布仍由维护者 manual promote。

## 日常检查

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/relayctl.sh status
```

例行维护：

```bash
cd /opt/lihan_ai_deploy/current
ENV_FILE=.env.production bash ops/relayctl.sh maintain
```

`maintain` 会依次运行已校验备份、存储清理和生产运行状态检查。

## 本地发布检查

在开发机上开 release PR 或合并前运行：

```bash
bash ops/relayctl.sh release-check
```

它会运行无密钥仓库 gate、扫描误提交的运行时文件和敏感模式、确认本地 AI 工作笔记仍被忽略，并执行本机 New API E2E。

如果本机恢复栈明确不可用：

```bash
SKIP_LOCAL_E2E=1 bash ops/release-readiness.sh
```

跳过本机 E2E 时，必须在 PR 或发布交接里写明原因。

## 发布

```bash
git fetch origin
git switch main
git pull --ff-only origin main

DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/relayctl.sh deploy-prepare
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/relayctl.sh deploy-smoke
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/relayctl.sh deploy-promote
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/relayctl.sh deploy-status
```

promote 后检查生产运行状态：

```bash
cd /opt/lihan_ai_deploy/current
COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh
```

## 恢复

如果 promote 时 SSH 中断：

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/relayctl.sh deploy-status
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/relayctl.sh recover
```

如果需要回滚：

```bash
DEPLOY_HOST=<deploy-user>@<origin-host> bash ops/relayctl.sh rollback <release-id>
```

## 发布规则

- `main` 就是生产。
- GitHub Actions 不 SSH 到生产服务器，也不读取生产 secrets。
- 生产 `promote` 必须人工执行。
- 备份只保存在服务器本地，不能提交进仓库。
- `docs/ai-dev/` 是本地工作上下文，必须保持 ignored。
- 默认使用官方 `calciumion/new-api:latest`；补丁镜像只作为临时回退路径。
