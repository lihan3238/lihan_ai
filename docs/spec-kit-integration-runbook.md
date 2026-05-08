# Spec Kit Integration Runbook

This project currently uses Superpowers for agent discipline and repo-native Spec Kit style templates for artifacts. GitHub Spec Kit can be added later as a tool layer, not as a replacement.

## Current Decision

- Superpowers remains the execution discipline layer: brainstorming, TDD, debugging, verification, and branch finishing.
- Repo-native `docs/templates/ai-dev/` remains the stable project workflow until official Spec Kit is tested in a sandbox.
- GitHub Spec Kit is treated as an optional upstream workflow/tooling provider.

## Why Not Initialize In This Repository First

`specify init --here` can create or merge `.specify/`, scripts, templates, agent commands, and agent skills. Run it in a scratch directory first so we can inspect generated files before touching this working repository.

## Prerequisites

WSL already has `uv` at `/home/lihan/.local/bin/uv`. If GitHub or Docker Hub access is unstable from WSL, use the Windows host proxy:

```bash
export HTTP_PROXY=http://10.88.0.6:10808
export HTTPS_PROXY=http://10.88.0.6:10808
export http_proxy=http://10.88.0.6:10808
export https_proxy=http://10.88.0.6:10808
```

## Phase 1: Install The Pinned CLI

Use the GitHub source, not a same-named package from PyPI:

```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@v0.8.7
specify version
specify check
```

If an older install exists:

```bash
uv tool install specify-cli --force --from git+https://github.com/github/spec-kit.git@v0.8.7
```

## Phase 2: Sandbox Initialization

Initialize a throwaway project first:

```bash
mkdir -p tmp/spec-kit-smoke
cd tmp/spec-kit-smoke
specify init my-project --integration codex --integration-options="--skills" --script sh --ignore-agent-tools
```

Inspect generated files:

```bash
find my-project -maxdepth 3 -type f | sort
```

Expected areas to review:

- `.specify/`
- generated scripts
- generated templates
- generated Codex skills or command files
- any agent instruction files

## Phase 3: Compare With Current Workflow

Before initializing in this repository, compare sandbox output against:

- `docs/development-workflow.md`
- `docs/templates/ai-dev/`
- `ops/ai-dev-check.sh`
- Superpowers skills already installed under the Codex plugin cache

Keep our project-specific rules:

- Research Gate before design.
- Wrapper-first before New API source changes.
- `Approved for implementation: yes` before tracked-file edits.
- Stop for destructive database, production, payment, secret, and core `vendor/new-api` changes.
- Use `ops/production-gate.sh` for operations/billing-sensitive changes.

## Phase 4: Repository Initialization Later

Only after sandbox review and a clean commit:

```bash
git status --short
bash tests/ai-dev-check.test.sh
bash tests/wrapper-infra.test.sh
bash tests/e2e-api-billing.test.sh
./scripts/verify-repo.ps1
```

Then initialize in this repository with explicit Codex skills integration:

```bash
specify init --here --integration codex --integration-options="--skills" --script sh --ignore-agent-tools
```

Use `--force` only after reviewing the file list that would be merged or overwritten.

## References Checked

- GitHub Spec Kit repository: https://github.com/github/spec-kit
- Spec Kit core command reference: https://github.github.io/spec-kit/reference/core.html
- Spec Kit installation guide: https://github.com/github/spec-kit/blob/main/docs/installation.md
