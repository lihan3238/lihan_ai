# Handoff

## Current State
The documentation i18n update adds Chinese mirrors for README and deployment/operations runbooks. English remains the source document set.

## Important Context
Chinese docs must not introduce behavior that does not exist in the English docs. Commands, variables, file paths, and script names stay in English.

## Verification
Local verification run:
- `bash tests/docs-i18n.test.sh`
- `bash tests/wrapper-infra.test.sh`
- `bash ops/ai-dev-check.sh docs/ai-dev/2026-05-10-docs-i18n-zh-cn`
- `./scripts/verify-repo.ps1`
- `git diff --check`

## Remaining Work
No runtime deployment is needed for this documentation-only change. Future deployment doc edits should update the paired Chinese docs and run `bash tests/docs-i18n.test.sh`.

## Risks
Future English doc updates may still require manual translation review. The test only checks mapped file presence and key command parity, not full semantic equivalence.
