# New API Full Feature Research

Research target: pinned upstream submodule `vendor/new-api` at `948780e3fae46c78ea2bedf02667831a215ced80`, runtime image `calciumion/new-api:latest` reporting `v1.0.0-rc.4`.

This is a development-readiness inventory, not a formal security audit. Before changing a feature, inspect the listed source paths and run the original behavior first.

## 1. Project Shape

New API is already a full AI gateway and asset-management system.

- Backend: Go, Gin, GORM.
- Frontend: React 19, TypeScript, Rsbuild, Base UI, Tailwind.
- Databases: SQLite, MySQL, PostgreSQL. Upstream requires all database changes to stay cross-database compatible.
- Cache: Redis plus memory cache.
- Architecture: `router -> controller -> service -> model`, with `relay/` for provider protocol adapters.
- Frontend package manager: Bun is preferred by upstream.

Important upstream rules:

- Use `common.Marshal` / `common.Unmarshal`, not direct `encoding/json` calls in business logic.
- Preserve optional relay request fields as pointers when zero/false values must be forwarded.
- For tiered or dynamic billing, read `vendor/new-api/pkg/billingexpr/expr.md` first.
- Do not remove or rename upstream New API / QuantumNous branding in upstream files.

## 2. Runtime And Setup

Relevant paths:

- `vendor/new-api/docker-compose.yml`
- `vendor/new-api/.env.example`
- `vendor/new-api/model/setup.go`
- `vendor/new-api/controller/setup.go`
- `vendor/new-api/router/api-router.go`

Capabilities:

- First-run setup flow at `/api/setup`, creating the root/admin user.
- Status and public configuration endpoints: `/api/status`, `/api/notice`, `/api/about`, `/api/pricing`, `/api/rankings`.
- Database migration is handled on app startup through GORM and custom migration helpers in `model/main.go`.
- Supports environment variables for SQL, Redis, memory cache, batch updates, timeouts, pprof, debug, session secret, LinuxDO endpoints, trusted redirect domains, and more.

Local deployment note:

- Our repo wraps the official image with PostgreSQL, Redis, Caddy, optional Cloudflare Tunnel ingress, local backups, and local dev port override.
- Business state lives in PostgreSQL. Do not use `docker compose down -v` unless resetting.

## 3. Relay API Surface

Relevant paths:

- `vendor/new-api/router/relay-router.go`
- `vendor/new-api/controller/relay.go`
- `vendor/new-api/relay/*`
- `vendor/new-api/relay/channel/*`

Supported relay endpoints include:

- OpenAI-compatible:
  - `GET /v1/models`
  - `GET /v1/models/:model`
  - `POST /v1/completions`
  - `POST /v1/chat/completions`
  - `POST /v1/responses`
  - `POST /v1/responses/compact`
  - `GET /v1/realtime`
  - `POST /v1/embeddings`
  - `POST /v1/images/generations`
  - `POST /v1/images/edits`
  - `POST /v1/audio/transcriptions`
  - `POST /v1/audio/translations`
  - `POST /v1/audio/speech`
  - `POST /v1/rerank`
  - `POST /v1/moderations`
- Claude-compatible:
  - `POST /v1/messages`
  - Anthropic model listing behavior when `x-api-key` and `anthropic-version` are present.
- Gemini-compatible:
  - `GET /v1beta/models`
  - `POST /v1beta/models/*path`
  - `POST /v1/models/*path`
  - `GET /v1beta/openai/models`
- Task/proxy routes:
  - Midjourney-style `/mj/...` and `/:mode/mj/...`
  - Suno `/suno/submit/:action`, `/suno/fetch`
  - Video/task routes in `router/video-router.go`

Explicitly not implemented in relay-router:

- OpenAI files endpoints.
- Fine-tunes endpoints.
- Image variations.
- Delete model endpoint.

## 4. Provider And Channel Coverage

Relevant paths:

- `vendor/new-api/constant/channel.go`
- `vendor/new-api/constant/api_type.go`
- `vendor/new-api/relay/channel/*`
- `vendor/new-api/model/channel.go`
- `vendor/new-api/controller/channel.go`
- `vendor/new-api/controller/channel-test.go`
- `vendor/new-api/controller/channel_upstream_update.go`

Provider adapters present in `relay/channel/`:

- OpenAI, Claude, Gemini, DeepSeek, Zhipu/GLM, Zhipu V4.
- Ali/DashScope, Baidu, Baidu V2, Tencent, VolcEngine, Xunfei, 360.
- OpenRouter, SiliconFlow, Moonshot, MiniMax, Mistral, Perplexity, xAI.
- AWS Bedrock, Vertex AI, Cloudflare, Cohere, Jina, Replicate.
- Ollama, Dify, Coze, Xinference, MokaAI, Submodel, LingYiWanWu.
- Jimeng and image/video/task-related adapters.
- Codex channel type and coding-plan special base URLs exist upstream; any use must be checked against upstream terms and compliance boundaries before productization.

Channel features:

- Channel type, name, status, priority, weight, group, tag, models, model mapping, base URL, balance, response time.
- Multi-key channel mode with random or polling key selection.
- Per-key status tracking for multi-key channels.
- Auto-ban / status-code mapping / status reason.
- Param override and header override per channel.
- Channel ability table ties group + model + channel status.
- Channel testing, batch operations, copy, tag operations, balance updates, model fetching, upstream model update detection/apply.

## 5. Channel Selection And Routing

Relevant paths:

- `vendor/new-api/middleware/distributor.go`
- `vendor/new-api/service/channel_select.go`
- `vendor/new-api/service/channel_affinity.go`
- `vendor/new-api/model/channel_satisfy.go`
- `vendor/new-api/model/ability.go`

Selection behavior:

- Token authentication determines user, token, token group, quota, model limits, and optional specific channel.
- Distributor parses model from OpenAI, Claude, Gemini, image, audio, realtime, task, Midjourney, and playground request shapes.
- Token-level model limits are enforced before channel selection.
- User group and token group determine usable channels.
- `auto` group support can select across configured auto groups.
- Cross-group retry exists for tokens using `auto` group.
- Channel priority is used with retry count; current group exhausts priorities before moving to next group.
- Channel affinity can prefer a previously successful channel for a model/group and records usage after successful requests.
- Multi-key channels select an enabled key and track disabled key state.
- Fallback/retry remains within the routing logic. Do not reimplement it unless a concrete upstream gap is proven.

Implication for our product:

- `default` and `vip` pools can likely be represented with New API groups, group ratios, model visibility, and token group settings before any code fork.
- Cheap or unstable supply should probably be configured as separate groups/channels, not custom routing code at first.

## 6. Users, Auth, And Security

Relevant paths:

- `vendor/new-api/model/user.go`
- `vendor/new-api/controller/user.go`
- `vendor/new-api/controller/oauth.go`
- `vendor/new-api/controller/custom_oauth.go`
- `vendor/new-api/controller/twofa.go`
- `vendor/new-api/controller/passkey.go`
- `vendor/new-api/middleware/auth.go`
- `vendor/new-api/middleware/rate-limit.go`
- `vendor/new-api/middleware/secure_verification.go`

Capabilities:

- Username/password login.
- Root/admin/common roles.
- Email verification and password reset.
- User status, groups, remarks, invite/affiliate fields, quota and used quota.
- OAuth: GitHub, Discord, OIDC, LinuxDO, WeChat, Telegram, and custom OAuth providers.
- OAuth binding/unbinding for users and admin.
- Passkeys/WebAuthn.
- TOTP 2FA and backup codes.
- Turnstile support.
- Critical route rate limits, email verification rate limits, search rate limits.
- Secure verification for sensitive actions such as channel key retrieval.
- Trusted redirect domains for payment redirect safety.
- Token read-only usage auth for usage endpoints.

Development implication:

- Do not build custom login or invite logic until we confirm New API's existing registration, OAuth, group, and affiliate controls are insufficient.

## 7. Tokens And Quota

Relevant paths:

- `vendor/new-api/model/token.go`
- `vendor/new-api/controller/token.go`
- `vendor/new-api/service/pre_consume_quota.go`
- `vendor/new-api/service/quota.go`
- `vendor/new-api/service/text_quota.go`
- `vendor/new-api/model/user_cache.go`
- `vendor/new-api/model/token_cache.go`

Token features:

- User-created API tokens.
- Token status, expiration, remaining quota, used quota, unlimited quota flag.
- Model limits per token.
- IP allowlist per token.
- Token group and cross-group retry.
- Batch token deletion and batch key reveal.
- Token key masking and sensitive-key retrieval controls.
- Redis cache for token lookup and quota updates.

Quota behavior:

- Pre-consume before upstream request.
- Actual settlement after upstream usage is known.
- Refund on failed request.
- Batch update mode for quota/request counters.
- User quota, token quota, channel used quota, request count and logs are updated.

## 8. Billing, Pricing, Subscriptions, And Payments

Relevant paths:

- `vendor/new-api/model/topup.go`
- `vendor/new-api/model/subscription.go`
- `vendor/new-api/model/pricing.go`
- `vendor/new-api/model/redemption.go`
- `vendor/new-api/controller/topup*.go`
- `vendor/new-api/controller/subscription*.go`
- `vendor/new-api/controller/billing.go`
- `vendor/new-api/service/billing_session.go`
- `vendor/new-api/service/billing.go`
- `vendor/new-api/service/tiered_settle.go`
- `vendor/new-api/setting/billing_setting/tiered_billing.go`
- `vendor/new-api/setting/ratio_setting/*`
- `vendor/new-api/pkg/billingexpr/expr.md`

Wallet/top-up:

- Top-up orders.
- Admin completion/reconciliation path.
- Redemption codes.
- Online payment integrations include EPay, Stripe, Creem, Waffo, Waffo/Pancake-related code.
- Payment provider/method mismatch guards exist in tests.

Subscriptions:

- Subscription plans, orders, user subscriptions.
- Admin can create/update plans, bind subscriptions, list user subscriptions, invalidate/delete subscriptions.
- User can view plans/self subscription and update billing preference.
- Subscription payment routes for EPay, Stripe, Creem.
- Background task expires/resets due subscriptions and cleans pre-consume records.

Billing sources:

- Wallet funding.
- Subscription funding.
- User preference supports `subscription_first`, `wallet_first`, `subscription_only`, `wallet_only`.
- Unified `BillingSession` handles pre-consume, reserve, settlement, refund, and token adjustment.

Pricing:

- Model ratio and group ratio.
- Group-group special ratio.
- Model price mode.
- Completion, cache, cache creation, image, audio, audio output ratios.
- Tiered/dynamic billing expressions with `p`, `c`, `len`, `cr`, `cc`, `cc1h`, `img`, `img_o`, `ai`, `ao`.
- Request-aware pricing functions: `param`, `header`, time functions, min/max/math helpers.
- Logs can include tiered billing expression details and matched tier.

Development implication:

- Our original "monthly quota package + balance fallback" goal overlaps heavily with upstream subscriptions and wallet billing. First attempt should be pure configuration and admin-console workflow, not custom tables.

## 9. Cache And Performance

Relevant paths:

- `vendor/new-api/common/redis.go`
- `vendor/new-api/common/disk_cache.go`
- `vendor/new-api/common/disk_cache_config.go`
- `vendor/new-api/middleware/cache.go`
- `vendor/new-api/middleware/performance.go`
- `vendor/new-api/controller/performance.go`
- `vendor/new-api/controller/perf_metrics.go`
- `vendor/new-api/service/text_quota.go`
- `vendor/new-api/setting/ratio_setting/cache_ratio.go`
- `vendor/new-api/setting/ratio_setting/exposed_cache.go`

Capabilities:

- Redis and memory cache.
- Request body disk cache for large/reusable request bodies.
- Disk cache stats and cleanup endpoints.
- Performance stats, logs, manual GC, reset stats.
- Prompt cache read/create ratios for billing.
- Claude 5-minute and 1-hour cache creation pricing logic.
- Cache token accounting in text quota settlement.
- Exposed cache settings in model ratio UI.

Development implication:

- Upstream already supports cache-aware billing. Do not build separate cached-token accounting before testing upstream logs and pricing screens.

## 10. Logs, Usage, Dashboard, And Observability

Relevant paths:

- `vendor/new-api/model/log.go`
- `vendor/new-api/model/usedata.go`
- `vendor/new-api/model/usedata_rankings.go`
- `vendor/new-api/controller/log.go`
- `vendor/new-api/controller/usedata.go`
- `vendor/new-api/controller/billing.go`
- `vendor/new-api/controller/pricing.go`
- `vendor/new-api/controller/rankings.go`
- `vendor/new-api/service/log_info_generate.go`

Capabilities:

- Admin usage logs and user self logs.
- Search and stats for logs.
- Token usage query.
- Dashboard billing usage/subscription endpoints.
- Quota date data by all users, specific users, or self.
- Rankings.
- Pricing endpoints and model pricing metadata.
- Log `other` JSON stores rich billing details including model/group ratios, subscription fields, tiered expression metadata, cache info, and task billing data.

Development implication:

- Before adding analytics, inspect what can be derived from logs/usedata/rankings and frontend dashboards.

## 11. Admin Settings And Frontend Coverage

Relevant paths:

- `vendor/new-api/web/default/src/features/*`
- `vendor/new-api/web/default/src/routes/*`
- `vendor/new-api/setting/*`
- `vendor/new-api/model/option.go`
- `vendor/new-api/controller/option.go`

Frontend feature areas:

- `setup`, `auth`, `dashboard`, `channels`, `keys`, `models`, `pricing`, `usage-logs`, `users`, `wallet`, `subscriptions`, `redemption-codes`, `profile`, `playground`, `chat`, `rankings`, `performance-metrics`, `system-settings`, `legal`, `about`.

System settings are split into:

- Auth settings.
- Billing settings.
- Content/site settings.
- Model/ratio settings.
- Operation settings.
- Security settings.
- Site/theme settings.

Backend settings include:

- Payment provider settings.
- Quota/token/check-in settings.
- Channel affinity and monitoring settings.
- Model ratios, group ratios, cache ratios, exposed ratios, compact suffixes.
- Tiered billing.
- Rate limits.
- Sensitive words.
- Legal/theme/OAuth/passkey/system settings.
- Performance and perf metrics settings.

Development implication:

- The admin console is likely enough for the first business experiments. Local code should start as docs/scripts/config presets, not backend forks.

## 12. Data Model Inventory

Core model structs in `vendor/new-api/model`:

- `User`, `UserBase`, `UserOAuthBinding`.
- `Token`.
- `Channel`, `ChannelInfo`, `Ability`, `AbilityWithChannel`.
- `Log`, `Stat`, `QuotaData`, ranking structs.
- `TopUp`, `Redemption`.
- `SubscriptionPlan`, `SubscriptionOrder`, `UserSubscription`, `SubscriptionPreConsumeRecord`.
- `Pricing`, `PricingVendor`, `Vendor`, `Model`, `BoundChannel`.
- `Task`, `Midjourney`.
- `PasskeyCredential`, `TwoFA`, `TwoFABackupCode`.
- `Option`, `Setup`, `Checkin`, `CheckinRecord`, `PrefillGroup`, `PerfMetric`, `CustomOAuthProvider`.

Development implication:

- Most platform concepts already have persistent models. Adding new tables should be a last resort.

## 13. Built-In Safety And Risk Controls

Relevant paths:

- `vendor/new-api/model/payment_method_guard_test.go`
- `vendor/new-api/controller/payment_webhook_availability_test.go`
- `vendor/new-api/common/ssrf_protection.go`
- `vendor/new-api/common/url_validator.go`
- `vendor/new-api/middleware/secure_verification.go`
- `vendor/new-api/middleware/rate-limit.go`
- `vendor/new-api/middleware/model-rate-limit.go`
- `vendor/new-api/service/error.go`

Controls found:

- Payment provider/method mismatch checks.
- Webhook availability checks.
- SSRF and URL validation helpers.
- Secure verification for sensitive operations.
- Global API, critical route, email verification, search, and model request rate limits.
- Channel auto-disable/auto-ban style behavior.
- Token model and IP limits.
- User disable/delete affects caches.
- Request ID and stats middleware.

Development implication:

- Payment changes are high-risk. Prefer upstream payment settings and tests; if modifying payment, add regression tests around duplicate callbacks, provider mismatch, amount mismatch, and idempotent crediting.

## 14. Development Strategy From This Research

Near-term development should not start by forking relay or billing logic.

Recommended order:

1. Initialize local New API and manually explore admin console.
2. Configure one safe provider channel, one user, one token, one model ratio, and one group.
3. Run real non-stream and stream calls through `/v1/chat/completions`.
4. Inspect logs and quota settlement.
5. Configure subscription/wallet behavior and verify whether it satisfies monthly package needs.
6. Configure cache ratios and inspect cached-token logging with supported upstreams.
7. Only after an upstream gap is proven, choose the smallest extension point.

Likely extension points if needed:

- Config/import scripts for repeatable channel/model/group setup.
- Operational scripts for backup, deployment, provider health checks, and cost reports.
- Thin UI copy/config changes in our wrapper documentation.
- Upstream PRs for generic bugs or missing admin-console ergonomics.
- Local fork only for business-specific workflows that cannot be configured upstream.

Avoid initially:

- Rewriting channel selection.
- Rewriting wallet/subscription billing.
- Building a separate payment order system.
- Adding cross-user response caches.
- Hardcoding provider/channel assumptions outside New API settings.

## 15. Open Questions Before Product Development

- Which upstream features satisfy invite-only registration, if any, without local code?
- Can subscription plans represent our intended monthly token packages exactly?
- Can groups and group ratios represent `default` and `vip` pools cleanly?
- Which payment provider is realistic for the first legal/operational setup?
- How much cached-token detail is visible in current logs for OpenAI/Claude/DeepSeek/Zhipu channels?
- Does New API's Codex/coding-plan support fit our compliance boundary, or should it remain disabled?
- Which admin workflows are too manual for operation and should become scripts or presets?

## 16. Health Monitoring Strategy

New API already exposes `/api/status`, stores channel `response_time` and `test_time`, records consume/error logs, and can automatically disable channels based on configured errors. For the current small private deployment, use New API's built-in admin visibility plus wrapper runtime checks before adding a separate status frontend.

Development implication:

- Internal health should be read from New API's existing channel, ability, and log tables before adding new runtime code.
- Any future public health view should be coarse-grained: API gateway, model pool, billing/account, and maintenance.
- Do not expose provider names, channel IDs, balances, quota sources, or internal errors on the public page.
- Avoid automatic wrapper-side channel disabling until the read-only advisor has produced enough operational history.
