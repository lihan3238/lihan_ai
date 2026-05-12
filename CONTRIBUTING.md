# Contributing

This project accepts small, reviewable community PRs that improve the wrapper around upstream New API.

## Good PRs

- Documentation fixes and clearer runbooks.
- Shell script safety improvements with tests.
- Docker Compose or env-template fixes that preserve existing deployment paths.
- Local E2E or repository verification improvements.
- New API upstream compatibility notes.

## Out Of Scope

- No production secrets, tokens, real private hostnames, or backup data.
- No automatic GitHub Actions deployment to the production server.
- No broad frontend fork of `vendor/new-api` unless the wrapper approach is clearly insufficient.
- No account resale, public growth hacking, or hidden telemetry features.
- No large unrelated refactors mixed into operational fixes.

## Before Opening A PR

Run:

```bash
bash ops/pre-commit.sh
bash ops/dev-gate.sh
```

For changes that affect browser flows, also run:

```bash
bash ops/local-new-api-e2e.sh
```

For production, backup, billing, migration, or security-sensitive changes, explain which live checks were run and which were skipped with `Reason:` and `Rerun:`.

## PR Shape

- Keep one purpose per PR.
- Include a short summary, verification commands, and residual risk.
- Update English and Chinese docs together when user-facing behavior changes.
- Keep local working notes under ignored `docs/ai-dev/`; copy only durable decisions into PR text or maintained runbooks.

## Community PR Boundary

Maintainers may ask PR authors to move implementation into upstream New API, split a large PR, remove private deployment assumptions, or add tests before review.
