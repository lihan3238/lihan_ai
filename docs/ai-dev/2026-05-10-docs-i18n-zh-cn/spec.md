# Spec

## Goal
Add Chinese documentation for the human-facing README and deployment/operations runbooks, with a test that catches missing translated files and key command drift.

## Success Criteria
- `README.zh-CN.md` exists and `README.md` links to it.
- `docs/zh-CN/` contains Chinese versions of the selected deployment and operations runbooks.
- `docs/i18n-map.md` records the English-to-Chinese document mapping.
- Tests verify that mapped docs exist, key commands and variables remain present, and Chinese docs contain no placeholder text.

## Scope
In scope: README, production deployment, edge proxy, migration, disaster recovery, backup, operations, and server buying guide.

Out of scope: translating `docs/ai-dev/`, Spec Kit templates, New API code maps, and source-code comments.

## Interfaces
- `README.zh-CN.md`
- `docs/zh-CN/*.md`
- `docs/i18n-map.md`
- `bash tests/docs-i18n.test.sh`

## Rules
Commands, environment variables, paths, domain placeholders, and script names remain untranslated. Operational explanations and safety warnings are translated into Chinese.
