# Plan

## Approach
Add a Chinese mirror for the human-facing entrypoint and deployment runbooks. Keep the English files as source docs and document the mapping in `docs/i18n-map.md`.

## Files
- Create `README.zh-CN.md`, `docs/i18n-map.md`, and `docs/zh-CN/`.
- Add `tests/docs-i18n.test.sh` for presence, command parity, and placeholder checks.
- Update `README.md`, `tests/wrapper-infra.test.sh`, and `scripts/verify-repo.ps1`.

## Compatibility
No runtime behavior changes. Script names, command blocks, paths, and environment variables remain unchanged.

## Verification
Run `bash tests/docs-i18n.test.sh`, wrapper tests, feature doc check, repository verification, and `git diff --check`.
