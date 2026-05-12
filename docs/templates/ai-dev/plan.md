# Plan

## Approach
Describe the implementation approach and why it is preferred.

## Files
List the main files or directories to create or modify.

## Compatibility
Describe API, database, config, and deployment compatibility.

## Rollback
Describe how to revert safely.

## Verification
List exact checks, tests, E2E runs, and any checks intentionally skipped with reasons.

## Change Impact
| Area | Impact |
| --- | --- |
| UI / API / Ops / Config / Docs | Describe the affected surface. |

## E2E Coverage Matrix
| Path | Command | Status | Evidence |
| --- | --- | --- | --- |
| Browser UI | `NEW_API_BASE_URL=http://localhost:3100 npm run e2e:web:new-api` | skipped | Reason: not affected by this change; Rerun: start local stack and run the command |
| API / billing | `NEW_API_TEST_TOKEN=... bash ops/e2e-api-billing.sh` | skipped | Reason: requires live token when billing changes; Rerun: create low-quota token and run the command |
| Deploy / ops | `COMPOSE_PROJECT_NAME=lihan_ai ENV_FILE=.env.production bash ops/check-production-runtime.sh` | skipped | Reason: requires production-like runtime when deploy changes; Rerun: run after promote or staging compose up |

## Documentation Impact
| Document | Update |
| --- | --- |
| README / runbook / feature docs | State whether it changed or why it did not need changes. |

## Usage/Test Guide
Write the exact usage explanation that should appear in the final response, including commands, expected output, and what the user should inspect.
