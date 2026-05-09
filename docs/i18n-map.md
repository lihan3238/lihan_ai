# Documentation I18N Map

English documentation remains the engineering source of truth. Chinese documents under `docs/zh-CN/` are synchronized translations for deployment and operations work.

## Mapped Documents

| English | Chinese |
| --- | --- |
| `README.md` | `README.zh-CN.md` |
| `docs/production-deployment-runbook.md` | `docs/zh-CN/production-deployment-runbook.md` |
| `docs/edge-proxy-runbook.md` | `docs/zh-CN/edge-proxy-runbook.md` |
| `docs/migration-runbook.md` | `docs/zh-CN/migration-runbook.md` |
| `docs/disaster-recovery-runbook.md` | `docs/zh-CN/disaster-recovery-runbook.md` |
| `docs/backup-strategy.md` | `docs/zh-CN/backup-strategy.md` |
| `docs/operations-runbook.md` | `docs/zh-CN/operations-runbook.md` |
| `docs/server-buying-guide.md` | `docs/zh-CN/server-buying-guide.md` |

## Maintenance Rules

- Keep commands, paths, environment variables, domains, and script names unchanged.
- Translate operational explanations, safety warnings, and recovery steps.
- Do not add extra operational behavior in Chinese-only docs.
- When any mapped English document changes deployment, backup, migration, or security behavior, update the paired Chinese document in the same change.
- Run `bash tests/docs-i18n.test.sh` before committing documentation changes.
