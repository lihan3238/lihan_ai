# Spec

## Goal
Deeply inspect repository code, documentation, and development workflow so the next development phase starts from a clean, non-conflicting baseline.

## Success Criteria
- Current workflow has an approved feature document set.
- No tracked scripts or docs contain unresolved placeholders outside intentional templates/tests.
- Existing verification commands pass.
- Any cleanup is evidence-based and documented.

## Scope
In scope: wrapper scripts, tests, docs, workflow templates, verification scripts, and runbooks outside `vendor/new-api`.

Out of scope: changing New API upstream source, production deployment, payment logic, database schema, or deleting backups/snapshots.

## Interfaces
The main checked interfaces are shell scripts under `ops/`, script tests under `tests/`, and workflow documents under `docs/`.

## Data
No database or API data should be modified. Any generated backups or snapshots remain ignored by git.

## Failure Modes
If verification fails, fix the root cause with a focused change and rerun the failing command. If a script is obsolete only by assumption, leave it in place and document the uncertainty.
