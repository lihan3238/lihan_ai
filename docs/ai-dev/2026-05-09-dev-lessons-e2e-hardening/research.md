# Research

## Sources
- Official documentation:
  - GitHub Spec Kit uses a specification-first workflow from specification to plan, tasks, and implementation: https://github.com/github/spec-kit
  - Playwright documents reusable authentication state with `storageState` and browser automation that can run locally or in CI: https://playwright.dev/docs/auth
  - Playwright documents Docker execution for repeatable browser tests: https://playwright.dev/docs/docker
  - The Twelve-Factor App separates config from code and treats backing services as attached resources: https://12factor.net/config and https://12factor.net/backing-services
- Mature adjacent projects:
  - New API already provides API, billing, channel, and log surfaces; this repo should verify those surfaces before replacing them.
  - Uptime Kuma provides a practical user-facing status page while internal scripts keep detailed diagnostics private.
- GitHub issues or release notes:
  - Browser E2E tools commonly require persisted login state and stable test data; using a manual browser plugin alone is not enough for CI-grade repeatability.
- Community discussions:
  - Recent local work showed that port conflicts and live billing checks are easy to mislabel unless each validation layer is named separately.

## Common Practice
Projects usually split validation into fast local checks, live integration checks, and browser checks. Fast checks run by default; live billing or provider checks require explicit credentials because they can mutate usage and spend money. Browser checks are split again into interactive acceptance testing and reproducible automation.

## Risks
- Treating a script smoke test as full E2E can hide broken browser or billing flows.
- Running real API E2E by default can unexpectedly spend token budget.
- Browser plugin validation is useful for human-assisted acceptance but is not a deterministic CI artifact.
- Windows PowerShell to WSL environment passing can silently drop secrets unless `WSLENV` is configured.
- Health checks in a noisy development setup should not use production thresholds.

## Decision
This repo will document four validation layers, add explicit local port and live billing wrapper scripts, require handoffs/final answers to state which layers ran, and keep Playwright as a later reproducible browser E2E phase. The current change does not install browser dependencies or modify New API source.
