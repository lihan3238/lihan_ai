# Documentation I18N Map

English documentation remains the engineering source of truth. Chinese documents under `docs/zh-CN/` are synchronized translations for deployment and operations work.

## Mapped Documents

| English | Chinese |
| --- | --- |
| `README.md` | `README.zh-CN.md` |
| `docs/production-deployment-runbook.md` | `docs/zh-CN/production-deployment-runbook.md` |
| `docs/release-deployment-runbook.md` | `docs/zh-CN/release-deployment-runbook.md` |
| `docs/cloudflare-saas-runbook.md` | `docs/zh-CN/cloudflare-saas-runbook.md` |
| `docs/edge-proxy-runbook.md` | `docs/zh-CN/edge-proxy-runbook.md` |
| `docs/migration-runbook.md` | `docs/zh-CN/migration-runbook.md` |
| `docs/disaster-recovery-runbook.md` | `docs/zh-CN/disaster-recovery-runbook.md` |
| `docs/git-branching-runbook.md` | `docs/zh-CN/git-branching-runbook.md` |
| `docs/cpa-runbook.md` | `docs/zh-CN/cpa-runbook.md` |
| `docs/backup-strategy.md` | `docs/zh-CN/backup-strategy.md` |
| `docs/operations-runbook.md` | `docs/zh-CN/operations-runbook.md` |
| `docs/ops-quick-reference.md` | `docs/zh-CN/ops-quick-reference.md` |
| `docs/maintainer-release-runbook.md` | `docs/zh-CN/maintainer-release-runbook.md` |
| `docs/user-quickstart.md` | `docs/zh-CN/user-quickstart.md` |
| `docs/user-guide.md` | `docs/zh-CN/user-guide.md` |
| `docs/server-buying-guide.md` | `docs/zh-CN/server-buying-guide.md` |
| `docs/new-api-small-circle-launch-runbook.md` | `docs/zh-CN/new-api-small-circle-launch-runbook.md` |
| `docs/new-api-small-circle-promo-ops.md` | `docs/zh-CN/new-api-small-circle-promo-ops.md` |

## Maintenance Rules

- Keep commands, paths, environment variables, domains, and script names unchanged.
- Translate operational explanations, safety warnings, and recovery steps.
- Do not add extra operational behavior in Chinese-only docs.
- When any mapped English document changes deployment, backup, migration, or security behavior, update the paired Chinese document in the same change.
- Run `bash tests/docs-i18n.test.sh` before committing documentation changes.
