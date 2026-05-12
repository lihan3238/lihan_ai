# Development Workflow

This repository uses a lightweight Spec Kit style workflow for AI-assisted development:

```text
Research -> Spec -> Plan -> Tasks -> Implement -> Verify -> Commit
```

The goal is continuity. Requirements, decisions, execution tasks, verification results, and handoff context must live in files, not only in chat.

Official GitHub Spec Kit `v0.8.7` is initialized in Codex skills mode. Its generated assets live in `.specify/`, `.agents/skills/speckit-*`, and `AGENTS.md`; operational details are tracked in `docs/spec-kit-integration-runbook.md`.

## Branch And Environment Policy

This repository uses a simple GitHub Flow style policy: `main = production`. Production origin servers deploy `main` by default, while local development happens on short-lived `codex/<topic>`, `feature/<topic>`, or `hotfix/<topic>` branches. See `docs/git-branching-runbook.md` for the full policy.

## GitHub Actions PR CI

Pull requests targeting `main` run the root GitHub Actions CI workflow. This is a fast, no-secret gate for repository hygiene: shell syntax, shell tests, Compose config rendering, whitespace checks, and `scripts/verify-repo.ps1 -SkipDocker`.

Default CI must not connect to production, read `.env.production`, require `NEW_API_TEST_TOKEN`, run `ops/production-gate.sh`, or perform backup/restore operations against a live database. Keep live billing E2E, production backups, restore drills, and release promotion checks in the local production gate and release deployment flow.

## Phased Delivery Pipeline

The default pipeline is:

```text
Pre-commit -> PR CI -> main runner validation -> manual production prepare/smoke/promote
```

- Pre-commit uses `pre-commit run --all-files`, backed by `bash ops/pre-commit.sh`. It stays lightweight and never runs Docker or browser E2E.
- PR CI is no-secret and never runs Playwright E2E.
- Pushes to `main` run GitHub-hosted post-merge validation only: `bash ops/dev-gate.sh` plus a disposable Docker Compose smoke on the runner.
- GitHub Actions must not read production deploy secrets, SSH to production, or run `ops/deploy-release.sh`.
- Production `prepare`, `smoke`, `promote`, `recover`, and `rollback` remain local/operator commands run from a trusted machine.

## Layered E2E Policy

E2E coverage is required as a matrix, not as a blanket GitHub Actions secret dependency. Every feature plan must include `E2E Coverage Matrix`, and every handoff must include `E2E Results`. Each affected path must either list a command that ran and the observed result, or a skipped entry with `Reason:` and `Rerun:`.

Use these default paths:

- Browser/UI: `bash ops/local-new-api-e2e.sh` for local restored stacks, or `NEW_API_BASE_URL=http://localhost:3100 npm run e2e:web:new-api` for a smoke-only check
- API/billing: `NEW_API_TEST_TOKEN=... NEW_API_TEST_MODEL=glm-5.1 bash ops/e2e-api-billing.sh`
- Deploy/ops: `COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh`
- Backup/migration: `ENV_FILE=.env.production bash ops/drill-restore-stack.sh backups/postgres/<dump>.dump`
- Config/env: `ENV_FILE=.env.production bash ops/preflight.sh` and `bash ops/sync-env-template.sh <target-env> .env.production.example`

PR CI only verifies that the repository and feature docs are structurally complete. Live E2E remains local/operator-run because it needs secrets, a running stack, or production-like state.

## Spec Kit And Superpowers

Spec Kit provides the upstream specification workflow and Codex skills:

```text
$speckit-constitution -> $speckit-specify -> $speckit-plan -> $speckit-tasks -> $speckit-implement
```

Superpowers remains the execution discipline layer for brainstorming, TDD, systematic debugging, verification, and branch finishing. If the two workflows disagree, this repository's safety gates win: Research Gate, `Approved for implementation: yes`, wrapper-first, high-risk stops, and production gate.

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

`AI_DEV_FEATURE_DIR` is optional for emergency diagnostics, but required for planned feature or workflow changes. It makes the production gate verify that the current feature documents still satisfy the Research -> Spec -> Plan -> Tasks approval contract, including E2E and documentation completion.

For lighter local edits, at least run:

```bash
bash ops/dev-gate.sh docs/ai-dev/<YYYY-MM-DD>-<topic>
bash ops/ai-dev-check.sh docs/ai-dev/<YYYY-MM-DD>-<topic>
bash tests/e2e-api-billing.test.sh
bash tests/wrapper-infra.test.sh
bash ops/preflight.sh
```

The GitHub Actions PR CI is an additional merge-time backstop, not a replacement for local verification. Operations, billing, deployment, backup, migration, and security changes still need the relevant local commands and a clear handoff of skipped live checks.

## Completion Handoff

After implementing a feature, update `handoff.md` before asking for review. The handoff must explain how to use and test the feature in enough detail for the user to reproduce the acceptance path: commands, UI pages, expected output, and what failures mean.

Run the local no-secret completion gate before finalizing routine work:

```bash
bash ops/dev-gate.sh docs/ai-dev/<YYYY-MM-DD>-<topic>
```

For operations, billing, deployment, backup, migration, or security changes, run the production gate or document why the live portion was skipped:

```bash
AI_DEV_FEATURE_DIR=docs/ai-dev/<YYYY-MM-DD>-<topic> bash ops/production-gate.sh
```
