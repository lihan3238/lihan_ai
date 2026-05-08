# AI API Relay V1 Requirements

## Goal

Build a small paid AI API relay for trusted users. V1 sells API access only. It does not include skill agents, custom workflow products, automatic payment, or account-pool supply.

## Required Capabilities

- Email registration with invite-only admission.
- OpenAI-compatible API surface through New API.
- Monthly quota packages backed by token/model-ratio billing.
- Ordinary cash balance for overage after monthly quota is exhausted.
- Standard and economy model pools.
- Manual payment confirmation and administrative quota grant.
- Usage logs that support revenue, cost, model, pool, user, and cached token analysis.
- Basic user, key, model, and channel rate limits.

## Channel Rules

Standard pool channels must be official APIs or high-trust authorized aggregators. Economy pool channels may use cheaper authorized supply, but users must explicitly select economy models and accept weaker stability. Economy failures must not automatically fall back to expensive standard channels.

## Billing Rules

Monthly package quota expires 30 days after grant and does not carry over. Deduct monthly quota first, cash balance second, gift quota last. If no balance remains, reject API calls before upstream dispatch.

## Future Roadmap

V1.5 adds channel health scores, invite rewards, automated economy-pool circuit breaking, upstream balance alerts, and package profit reports. V2 adds research-oriented skill agents for paper reading, literature review, experiment notes, and review responses.
