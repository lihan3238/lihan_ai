# Tasks

Approved for implementation: yes

## Implementation Tasks
- [x] Run repository static searches for stale workflow, placeholders, and conflicting commands.
- [x] Run current lightweight verification suite.
- [x] Fix only proven conflicts or stale references.
- [x] Update handoff with commands run and remaining risk.
- [x] Commit a coherent cleanup change.

## High-Risk Stops
- [x] No destructive database operations were run.
- [x] No production deployment was run.
- [x] No payment or secret changes were made.
- [x] No `vendor/new-api` core source was modified.
