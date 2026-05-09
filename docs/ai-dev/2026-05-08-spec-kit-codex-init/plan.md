# Plan

## Approach
Run the pinned Spec Kit CLI in Codex skills mode from the repository root. Commit generated workflow assets, then add project-level tests and documentation so future agents can rely on both Spec Kit and the existing wrapper-first gates.

## Files
- Create `.specify/`, `.agents/skills/speckit-*`, and `AGENTS.md` with `specify init`.
- Create `tests/spec-kit-init.test.sh`.
- Modify `.gitignore`, `README.md`, `docs/development-workflow.md`, `docs/spec-kit-integration-runbook.md`, and `scripts/verify-repo.ps1`.

## Compatibility
No public API, Docker, database, or New API source compatibility is affected. Spec Kit's shell scripts are generated with `--script sh` to fit the existing WSL/Linux operations tooling.

## Rollback
Revert the commit that adds `.specify/`, `.agents/skills/speckit-*`, `AGENTS.md`, the test, and documentation changes. Runtime containers and PostgreSQL state are unaffected.

## Verification
Run:

```bash
bash ops/ai-dev-check.sh docs/ai-dev/2026-05-08-spec-kit-codex-init
bash tests/spec-kit-init.test.sh
bash tests/ai-dev-check.test.sh
bash tests/wrapper-infra.test.sh
bash tests/e2e-api-billing.test.sh
bash tests/ops-profile.test.sh
bash ops/preflight.sh
./scripts/verify-repo.ps1
git diff --check
git status --short
```
