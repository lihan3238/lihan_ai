# Tasks

Approved for implementation: yes

## Implementation Tasks
- [x] Write failing tests for production deployment and migration safety gates.
- [x] Add production and edge Docker Compose layers.
- [x] Add bootstrap, deploy, remote verify, off-site backup, migration preflight, and final migration scripts.
- [x] Add feature documents and operator runbooks.
- [x] Update repository verification and existing runbooks.
- [x] Run verification commands and record results.

## High-Risk Stops
- [x] Do not modify `vendor/new-api`.
- [x] Do not run production deployment from the local development machine.
- [x] Do not stop a source server or restore over a target database without `CONFIRM_FINAL_CUTOVER=yes`.
- [x] Do not commit `.env.production`, backups, snapshots, or restic credentials.
