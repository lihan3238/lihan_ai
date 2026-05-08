# Development Workflow

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
bash ops/production-gate.sh
```

For lighter local edits, at least run:

```bash
bash tests/e2e-api-billing.test.sh
bash tests/wrapper-infra.test.sh
bash ops/preflight.sh
```
