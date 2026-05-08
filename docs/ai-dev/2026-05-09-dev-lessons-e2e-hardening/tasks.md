# Tasks

Approved for implementation: yes

## Implementation Tasks
- [x] Write failing tests for local port checking and DB-token live billing wrapper.
- [x] Run the new tests and confirm they fail because the scripts do not exist.
- [x] Implement `ops/check-local-ports.sh`.
- [x] Implement `ops/live-e2e-billing-from-db-token.sh`.
- [x] Run the new tests and confirm they pass.
- [x] Add development lessons, E2E strategy, and manual Web test runbook.
- [x] Update workflow, handoff template, README, operations runbook, production gate, wrapper test, and repo verification.
- [x] Run the full planned verification set.
- [x] Record live E2E/browser status and manual Web test flow in the final response.

## High-Risk Stops
- [x] Confirm before destructive database operations.
- [x] Confirm before production deployment.
- [x] Confirm before payment or secret changes.
- [x] Confirm before modifying `vendor/new-api` core source.
