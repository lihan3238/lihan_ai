# Development Workflow

This repository uses a lightweight Spec Kit style workflow for AI-assisted development:

```text
Research -> Spec -> Plan -> Tasks -> Implement -> Verify -> Commit
```

The goal is continuity. Requirements, decisions, execution tasks, verification results, and handoff context must live in files, not only in chat.

Official GitHub Spec Kit integration is tracked separately in `docs/spec-kit-integration-runbook.md`. Do not run `specify init --here` in this repository until the sandbox process in that runbook has been completed.

## Research Gate

Every new product or operations requirement starts with a short external research pass before design or implementation.

Use this source order:

- Official documentation for New API, Docker, PostgreSQL, payment providers, or upstream model providers.
- Mature adjacent projects such as LiteLLM Proxy and Open WebUI.
- GitHub issues, PRs, and release notes for real upgrade or migration failures.
- Community discussions only after primary sources are checked.

Each design must record:

- How other projects usually solve the same problem.
- Common failure modes or operational traps.
- What this repository will copy, avoid, or simplify.

Research is mandatory for payment, backup, restore, upgrade, configuration migration, health checks, cache billing, and production deployment work.

## Feature Document Set

Each new feature or operations change gets a directory:

```text
docs/ai-dev/<YYYY-MM-DD>-<topic>/
  research.md
  spec.md
  plan.md
  tasks.md
  handoff.md
```

Use the templates in `docs/templates/ai-dev/`.

Before implementation, run:

```bash
bash ops/ai-dev-check.sh docs/ai-dev/<YYYY-MM-DD>-<topic>
```

`tasks.md` must contain exactly:

```text
Approved for implementation: yes
```

Without that approval line, agents may continue planning but must not change repo-tracked files.

## Implementation Gate

After approval, implementation may proceed continuously in the local development environment. Stop and ask before:

- Destructive database operations.
- Production deployment or DNS changes.
- Payment, webhook, or secret changes.
- Deleting user data, backups, logs, or snapshots.
- Modifying core `vendor/new-api` relay, billing, auth, or payment source.

Every implementation must update the feature `handoff.md` or final response with commands run, E2E status, skipped checks, and residual risk.

## Wrapper-First Rule

Prefer wrapper, compose, script, runbook, and test changes before changing `vendor/new-api`.

Only modify upstream New API source after:

- The original admin console and API behavior have been tested.
- The gap is documented.
- The wrapper approach is insufficient.
- A rollback path and E2E check exist.

## Verification Gate

Before pushing changes that affect operations or billing:

```bash
export AI_DEV_FEATURE_DIR="docs/ai-dev/<YYYY-MM-DD>-<topic>"
bash ops/production-gate.sh
```

`AI_DEV_FEATURE_DIR` is optional for emergency diagnostics, but required for planned feature or workflow changes. It makes the production gate verify that the current feature documents still satisfy the Research -> Spec -> Plan -> Tasks approval contract.

For lighter local edits, at least run:

```bash
bash ops/ai-dev-check.sh docs/ai-dev/<YYYY-MM-DD>-<topic>
bash tests/e2e-api-billing.test.sh
bash tests/wrapper-infra.test.sh
bash ops/preflight.sh
```
