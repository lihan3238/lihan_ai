# Git 分支 Runbook

## 策略

`main = production`。`main` 分支必须始终代表可部署到生产 origin 的代码。生产部署默认使用 `DEPLOY_REF=main` 和 `DEPLOY_ENV=production`。

所有变更都使用短生命周期分支：

- `codex/<topic>` 用于 AI/Codex 辅助开发。
- `feature/<topic>` 用于人工功能开发。
- `hotfix/<topic>` 用于生产紧急修复，从 `main` 拉出。

不要创建长期 `develop` 分支。未来如果需要 staging，应增加独立 staging 服务器和部署环境，而不是改变分支模型。

## Pull Request 规则

- 所有非小型变更都通过 PR。
- 合并到 `main` 时优先使用 squash merge 或 rebase merge，保持历史清晰。
- PR 合并后删除远程功能分支。
- 除小型文档或运维修正外，PR 需要包含 `docs/ai-dev/<YYYY-MM-DD>-<topic>/` feature 文档；小修正要在 PR 描述中说明。
- 合并到 `main` 前等待 GitHub Actions PR CI 通过。CI 门禁刻意不使用 secrets，不部署、不运行 production-gate，也不接触 live databases。
- 合并前运行相关测试。涉及运维、计费、部署、备份、迁移和安全的变更，必须通过 `docs/development-workflow.md` 中的项目门禁。

## 环境隔离

- 本地开发使用任意短生命周期分支、`.env` 和 `docker-compose.dev.yml`。
- 生产 origin 使用 `main`、`.env.production` 和 `docker-compose.prod.yml`。
- Edge 节点使用 `main`、`.env.edge` 和 `docker-compose.edge.yml`。
- 生产 secrets 不进入 git，也不复制到 edge 节点。

## 部署规则

正常生产部署：

```bash
DEPLOY_HOST=root@x.x.x.x DEPLOY_PATH=/opt/lihan_ai DEPLOY_REF=main bash ops/deploy-prod.sh
```

部署脚本会拒绝 `DEPLOY_ENV=production` 且 `DEPLOY_REF` 不是 `main` 的部署。

强烈不建议把非 `main` 分支部署到生产。若紧急情况下无法避免，先记录原因，再运行：

```bash
ALLOW_NON_MAIN_PROD_DEPLOY=1 DEPLOY_ENV=production DEPLOY_REF=hotfix/example DEPLOY_HOST=root@x.x.x.x bash ops/deploy-prod.sh
```

紧急问题解决后，把修复合并回 `main`，并重新部署 `main`。

## Hotfix 流程

```bash
git fetch origin
git switch main
git pull --ff-only origin main
git switch -c hotfix/<topic>
```

只做最小安全修复，运行验证，开 PR，合并到 `main`，再部署 `main`。

## 本地分支清理

PR 合并且生产已经切到 `main` 后：

```bash
git fetch origin --prune
git switch main
git pull --ff-only origin main
git submodule update --init --recursive
git branch -d codex/<topic>
```

确认没有任何活跃环境依赖该分支后，再删除远程分支：

```bash
git push origin --delete codex/<topic>
```

## 回滚

优先在 `hotfix/<topic>` 分支上向前修复并部署 `main`。如果必须立即回滚，部署一个已知可用的 `main` commit 并记录事故。不要让生产 origin 长期跟踪非 `main` 分支。
