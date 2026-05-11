# New API Code And Feature Map

This map records what exists upstream before any local customization. The goal is to avoid rebuilding features New API already has.

## Runtime And Deployment

- Official image: `calciumion/new-api:latest`.
- Upstream compose: `vendor/new-api/docker-compose.yml` runs New API with PostgreSQL and Redis.
- Local wrapper compose in this repository keeps the same official image and adds safer env interpolation, local port override, Caddy for production HTTPS, optional Cloudflare Tunnel ingress, and local backup tooling.
- Main environment concepts are in `vendor/new-api/.env.example`, including database, Redis, cache sync, relay timeouts, session secret, LinuxDO endpoints, node type, and trusted redirect domains.

## Backend Structure

- `controller/`: HTTP handlers for admin, users, tokens, channels, billing, pricing, top-up, subscriptions, OAuth, logs, setup, playground, tasks, and provider-specific operations.
- `router/`: API, relay, dashboard, video, and web route registration.
- `middleware/`: auth, request logging, rate limiting, model rate limiting, distributor, cache, CORS, recovery, stats, secure verification, and Turnstile checks.
- `model/`: database entities and persistence logic for users, channels, tokens, quotas, pricing, subscriptions, redemptions, logs, options, passkeys, model metadata, tasks, and vendor metadata.
- `service/`: quota accounting, billing, pre-consume logic, channel selection, affinity, HTTP client, token counting, pricing helpers, subscriptions, payment integrations, notification limits, and task billing.
- `relay/`: OpenAI-compatible relay plus provider adaptors, stream handling, token billing helpers, request validation, model mapping, and protocol conversion.
- `setting/`: admin-configurable system, operation, payment, pricing, ratio, model, performance, rate-limit, legal, theme, and provider-specific settings.
- `web/default/`: React frontend for setup, admin console, user console, channel/config screens, tables, notifications, themes, auth state, and API calls.

## Built-In Product Capabilities

- OpenAI-compatible API relay and provider-specific adapters.
- Multiple provider families, including OpenAI, Claude, Gemini, DeepSeek, Zhipu/GLM, SiliconFlow, OpenRouter, Ali, Baidu, Tencent, Volcengine, AWS, Vertex, Cohere, Jina, Mistral, Perplexity, xAI, Ollama, Dify, Replicate, Minimax, Moonshot, and others.
- Chat, responses, embeddings, images, audio, rerank, realtime/websocket, Midjourney-style tasks, and video/task flows.
- Channel management with model mappings, health/testing, sync/update flows, channel selection, affinity, and retry/distribution middleware.
- User, token, group, quota, and model permission management.
- Usage logs, dashboard data, ranking/usedata reports, billing sessions, and pricing metadata.
- Built-in payment/top-up/subscription paths, including Stripe, EPay, Creem, Waffo/Pancake-related integrations, redemption, and payment webhook availability checks.
- OAuth and authentication support, including LinuxDO, GitHub, Discord, Telegram, OIDC, passkeys, TOTP/2FA, and custom OAuth providers.
- Cache and billing controls, including memory/Redis cache, token/quota accounting, cache ratio settings, exposed cache settings, and provider cache billing support noted in upstream README.
- Admin-configurable operation settings such as check-in, quota, tokens, payment, monitoring, channel affinity, status code ranges, and rate limits.
- Security-related controls including SSRF protection helpers, trusted redirect domains, secure verification, CORS middleware, Turnstile checks, request IDs, and recovery middleware.

## Customization Rule

Before adding any local feature, first find the existing upstream implementation in `vendor/new-api`, run the original behavior, and document why the upstream feature is insufficient. Local changes should prefer configuration, upstream PRs, or thin wrappers before forking core relay/billing logic.
