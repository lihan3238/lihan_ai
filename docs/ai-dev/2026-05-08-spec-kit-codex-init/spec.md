# Spec

## Goal
Make GitHub Spec Kit `v0.8.7` usable in this repository through Codex skills mode, with `specify init --here` completed and verified.

## Success Criteria
- `specify init --here --offline --integration codex --integration-options="--skills" --script sh --ignore-agent-tools --no-git --force` generates the expected Spec Kit files in the repository.
- Repository verification confirms the expected `.specify`, `.agents/skills/speckit-*`, and `AGENTS.md` files exist.
- Existing AI development gates remain documented and still pass.

## Scope
In scope: Spec Kit Codex skills initialization, documentation updates, ignore rules, and repository verification tests.

Out of scope: Claude Code initialization, production deployment, New API source changes, database changes, payment changes, and `.env` edits.

## Interfaces
- Codex skills: `$speckit-constitution`, `$speckit-specify`, `$speckit-plan`, `$speckit-tasks`, `$speckit-implement`.
- Generated directories: `.specify/` and `.agents/skills/speckit-*`.
- Generated context file: `AGENTS.md`.
- Verification command: `bash tests/spec-kit-init.test.sh`.

## Data
No runtime data, secrets, database schema, or New API configuration are changed. Only repository workflow assets and documentation are persisted.

## Failure Modes
If Spec Kit generation conflicts with existing files, inspect the diff and prefer preserving project-specific rules. If generated `.agents` content includes anything outside `skills`, stop before committing and either ignore or remove that content. If verification fails, do not proceed to production-gate or future development until the workflow files are reconciled.
