# Small Circle Launch Configuration Spec

## Summary

Prepare the repository for a small friend-only New API package launch without adding payment automation or broad frontend customization.

## User Acceptance Path

- Operator can read one runbook and configure site copy, packages, groups, and manual activation.
- Operator can run one browser E2E command to verify Users page `Manage Bindings` and `Manage Subscriptions`.
- Operator can keep the official image by default or explicitly enable `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1` for the pinned dropdown `onSelect` patched image.

## Requirements

- Use station quota wording and explicitly state it is not official USD balance.
- Document the 5/50/100/200/1000 CNY packages and reset periods.
- Keep `default` and `vip` as the only active operating groups.
- Prefer `calciumion/new-api:latest`; use `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1` only for the temporary dropdown fix until the official image ships it.
- Do not generate Linux.do promotional copy.
