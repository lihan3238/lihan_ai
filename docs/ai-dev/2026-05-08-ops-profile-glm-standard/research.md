# Research

## Sources
- LiteLLM virtual keys documentation: virtual keys control model access and track spend by key, user, and team. https://docs.litellm.ai/docs/proxy/virtual_keys
- Open WebUI groups documentation: groups are used for resource access control such as models, tools, prompts, and knowledge bases. https://docs.openwebui.com/features/workspace/groups/
- New API FAQ: no-channel errors should be checked through user group, channel group, and channel model settings; quota uses group and model multipliers. https://github.com/QuantumNous/new-api-docs/blob/main/docs/en/support/faq.md
- Local New API source inventory: `docs/new-api-full-research.md`.

## Common Practice
Gateway products usually separate user/key access, model/channel grouping, quota accounting, and spend reporting. Mature systems expose these controls as configuration first, then add automation after the operator has a known-good baseline.

## Risks
- Automatically writing New API admin configuration can bypass upstream UI validation or session protections.
- Database direct writes can leave channels and abilities inconsistent.
- Printing profile validation output must not reveal channel keys, API tokens, passwords, or session secrets.
- Running live E2E during profile validation would create hidden token cost.

## Decision
Implement a read-only ops profile validator first. It checks the configured intent against PostgreSQL and optionally checks `/v1/models` visibility when `NEW_API_TEST_TOKEN` is provided, but it never creates channels, users, tokens, subscriptions, or payments.
