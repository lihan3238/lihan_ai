# Tasks

Approved for implementation: yes

## Implementation Tasks
- [x] Write failing tests for missing ops-profile script and profile.
- [x] Implement GLM standard profile and read-only validator.
- [x] Cover missing file, bad JSON, missing required field, fake DB pass/fail, and token-redaction behavior.
- [x] Wire validator into production gate and repo verification.
- [x] Update README and operations runbooks.
- [x] Run final verification suite and commit a coherent change.

## High-Risk Stops
- [x] No destructive database operations are needed.
- [x] No production deployment is needed.
- [x] No payment or secret changes are needed.
- [x] No `vendor/new-api` core source changes are needed.
