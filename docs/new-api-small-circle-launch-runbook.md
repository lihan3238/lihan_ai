# New API Small Circle Launch Runbook

This runbook is for a small friend-only New API launch. It keeps the first stage configuration-first: no landing page, no online payment, no custom billing tables, and no broad New API frontend fork.

## Positioning

Public promise:

- Stable and safe relay backed by officially purchased API supply.
- Freedom to choose strong models across providers instead of being locked to one vendor.
- Small circle operation with manual support, fair use, and no resale.

Avoid these promises:

- Unlimited usage.
- Guaranteed lowest price.
- Any claim that station quota is the same as official USD balance.
- Linux.do promotional posting. Use Linux.do only as market research; this launch copy is for WeChat Moments and private chats.

## Admin Site Configuration

Configure this in the New API admin console before sharing the site:

- Site name, Logo, public server address, docs link, About content, FAQ, and announcements.
- Currency display: use a custom display type and label it as station quota.
- Public text must include: station quota is not official USD balance.
- Groups stay simple: `default` for normal friends and `vip` for manually granted high-priority users.

Suggested announcement:

```text
This is a small friend-only AI API relay. Supply is purchased through official API channels where possible, and stability is preferred over lowest-price routing. Usage is measured in station quota, not official USD balance. Do not resell, share accounts, or run abusive high-concurrency traffic.
```

## Packages

Use New API subscription plans and manual activation. Payment stays outside New API for now.

| Package | Price | Station quota | Reset / validity | Group |
| --- | ---: | ---: | --- | --- |
| Trial | 5 CNY | 20 | 1 day | `default` |
| Basic | 50 CNY | 30 | weekly reset | `default` |
| Plus | 100 CNY | 100 | weekly reset | `default` |
| Pro | 200 CNY | 250 | weekly reset | `default` |
| Heavy | 1000 CNY | 150 | daily reset | `vip` |

Manual activation flow:

1. Receive payment in WeChat.
2. Create or find the user in New API.
3. Assign `default` or `vip`.
4. Bind the matching subscription plan.
5. Send the user the API base URL, token creation steps, and fair use notice.

## Frontend Patch Policy

Production should keep using `calciumion/new-api:latest` by default. While the upstream image does not include the fix,
use the pinned local build path:

```env
DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1
LOCAL_NEW_API_IMAGE=lihan-ai/new-api:local
```

There is one known operational blocker in the new frontend: the Users page row menu can fail to open `Manage Bindings` and `Manage Subscriptions` when `DropdownMenuItem onSelect` is not wired. The temporary local fix is submodule commit `5741c359` (`fix(default): support dropdown menu onSelect`) from `lihan3238/new-api`. Upstream issue #4692 and upstream PR #4787 are not treated as fixed until the official image includes the equivalent patch.

Temporary custom image rules:

- Use `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=1` only while admin E2E proves the official image still fails.
- The temporary image may only contain the dropdown `onSelect` fix.
- Do not mix package pricing, brand copy, payment code, or billing logic into the custom frontend.
- After upstream PR #4787 lands and the official image passes the same E2E, set `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD=0` and return to `calciumion/new-api:latest`.
- At the same time, move `.gitmodules` and `vendor/new-api` back to the official `QuantumNous/new-api` upstream commit that contains the fix.

## Admin Frontend E2E

Run this before launch and before deciding whether to use a temporary custom image:

```bash
NEW_API_BASE_URL=https://api.lihan3238.com \
NEW_API_ADMIN_USERNAME=<admin> \
NEW_API_ADMIN_PASSWORD=<password> \
bash ops/check-new-api-admin-frontend.sh
```

When testing the temporary local patch, add:

```bash
CHECK_LOCAL_NEW_API_PATCH=1 \
NEW_API_BASE_URL=http://localhost:3100 \
NEW_API_ADMIN_USERNAME=<admin> \
NEW_API_ADMIN_PASSWORD=<password> \
bash ops/check-new-api-admin-frontend.sh
```

Expected result:

- Users page loads.
- Row action menu opens.
- `Manage Bindings` opens the account binding dialog.
- `Manage Subscriptions` opens the user subscription management dialog.
- If `CHECK_LOCAL_NEW_API_PATCH=1`, `npm run typecheck`, `npm run build`, and the dropdown-menu.test.tsx patch check are run against `vendor/new-api/web/default`.

## WeChat Moments Copy

```text
I have stabilized a small AI API relay for friends.

What it is for:
1. Stable and safer access backed by officially purchased API supply where possible.
2. Freedom to choose strong models across providers instead of being locked to one vendor.

Good fit: coding, AI clients, small automation tools, study and testing.
Not a good fit: resale, account sharing, abusive high-concurrency traffic, or lowest-price unlimited usage.

Current friend-only packages:
5 CNY trial: 20 station quota / 1 day
50 CNY: 30 station quota / weekly reset
100 CNY: 100 station quota / weekly reset
200 CNY: 250 station quota / weekly reset
1000 CNY: 150 station quota / daily reset, high-frequency users

Station quota is an internal site quota, not official USD balance.
Message me on WeChat if you want to try it; I will activate it manually.
```

## Acceptance Checklist

- Site copy uses station quota and says not official USD balance.
- `default` and `vip` are the only active business groups.
- All five subscription packages exist and match the table above.
- Manual activation is documented for the operator and users.
- `ops/check-new-api-admin-frontend.sh` passes against the launch target.
- `DEPLOY_INCLUDE_LOCAL_NEW_API_BUILD` is either `0` for the official image or explicitly recorded as `1` for the dropdown fix.
