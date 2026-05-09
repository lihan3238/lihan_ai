# Git Branching Runbook

## Policy

`main = production`. The `main` branch must always represent code that can be deployed to the production origin. Production deploys default to `DEPLOY_REF=main` and `DEPLOY_ENV=production`.

Use short-lived branches for all changes:

- `codex/<topic>` for AI-assisted work.
- `feature/<topic>` for manual feature work.
- `hotfix/<topic>` for urgent production fixes, branched from `main`.

Do not create a long-lived `develop` branch. If staging is needed later, add a separate staging server and deployment environment rather than changing the branch model.

## Pull Request Rules

- Open a PR for every non-trivial change.
- Prefer squash merge or rebase merge into `main` to keep history readable.
- Delete the remote feature branch after the PR is merged.
- Include feature docs under `docs/ai-dev/<YYYY-MM-DD>-<topic>/`, unless the PR is a small documentation or operations correction and the PR description says so.
- Run the relevant tests before merge. Operations, billing, deployment, backup, migration, and security changes must pass the project gates documented in `docs/development-workflow.md`.

## Environment Isolation

- Local development uses any short-lived branch, `.env`, and `docker-compose.dev.yml`.
- Production origin uses `main`, `.env.production`, and `docker-compose.prod.yml`.
- Edge nodes use `main`, `.env.edge`, and `docker-compose.edge.yml`.
- Production secrets stay out of git and do not move to edge nodes.

## Deployment Rules

Normal production deploy:

```bash
DEPLOY_HOST=root@x.x.x.x DEPLOY_PATH=/opt/lihan_ai DEPLOY_REF=main bash ops/deploy-prod.sh
```

The deploy script refuses `DEPLOY_ENV=production` with a non-`main` `DEPLOY_REF`.

Emergency non-main production deploys are strongly discouraged. If unavoidable, document the reason first, then run:

```bash
ALLOW_NON_MAIN_PROD_DEPLOY=1 DEPLOY_ENV=production DEPLOY_REF=hotfix/example DEPLOY_HOST=root@x.x.x.x bash ops/deploy-prod.sh
```

After the emergency is resolved, merge the fix into `main` and redeploy `main`.

## Hotfix Flow

```bash
git fetch origin
git switch main
git pull --ff-only origin main
git switch -c hotfix/<topic>
```

Make the smallest safe fix, run verification, open a PR, merge to `main`, then deploy `main`.

## Local Branch Cleanup

After a PR is merged and production has moved to `main`:

```bash
git fetch origin --prune
git switch main
git pull --ff-only origin main
git submodule update --init --recursive
git branch -d codex/<topic>
```

Delete the remote branch only after confirming no active environment depends on it:

```bash
git push origin --delete codex/<topic>
```

## Rollback

Prefer fixing forward on a `hotfix/<topic>` branch and deploying `main`. If an immediate rollback is required, deploy a known-good `main` commit and document the incident. Do not make the production origin track a long-lived non-main branch.
