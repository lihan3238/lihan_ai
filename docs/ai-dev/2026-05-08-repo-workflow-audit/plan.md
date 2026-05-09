# Plan

## Approach
Use the current AI development workflow to audit itself. Run static searches, execute script tests, identify concrete conflicts, and make narrowly scoped fixes.

## Files
Likely files to update are `docs/development-workflow.md`, `docs/spec-kit-integration-runbook.md`, `README.md`, `ops/ai-dev-check.sh`, and `scripts/verify-repo.ps1` if evidence shows a conflict or missing check.

## Compatibility
No public API, Docker runtime, database, or New API source behavior should change.

## Rollback
Revert the audit commit. Generated ignored files under `backups/` and `snapshots/` do not affect rollback.

## Verification
Run `bash ops/ai-dev-check.sh docs/ai-dev/2026-05-08-repo-workflow-audit`, script tests, `bash ops/preflight.sh`, `./scripts/verify-repo.ps1`, `git diff --check`, and targeted real E2E only if script logic changes can affect relay/billing behavior.
