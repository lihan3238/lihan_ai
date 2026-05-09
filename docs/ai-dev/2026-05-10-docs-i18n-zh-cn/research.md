# Research

## Sources
- Existing repository documentation: `README.md`, deployment runbooks, backup, operations, and server buying guide.
- Existing repository workflow: `docs/development-workflow.md`, `tests/wrapper-infra.test.sh`, and `scripts/verify-repo.ps1`.

## Common Practice
Operational projects usually keep the primary engineering docs in one language, then maintain localized operator-facing docs with the same command blocks and variable names. The critical risk is not translation style; it is command drift between languages.

## Risks
- Chinese docs may become stale when English deployment docs change.
- Translated command blocks could accidentally alter file paths, environment variables, or safety confirmations.
- Internal design documents do not need translation and would create maintenance noise if included.

## Decision
Keep English as the source document set, add Chinese mirrors only for human-facing deployment and operations docs, and enforce key-command parity with a lightweight shell test.
