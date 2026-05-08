# Upstream Cache Observability

## V1 Scope

V1 does not cache user responses and does not rewrite user prompts. The only cache optimization is upstream API prompt/context cache observability and safe routing hints that do not change request semantics.

## Metrics To Track

- Provider, model, pool, channel, user, and API key.
- Input tokens, output tokens, and cached input tokens.
- OpenAI-style `cached_tokens` fields when returned by the provider.
- Claude-style cache creation and cache read token fields when returned by the provider.
- Estimated savings from cached input token pricing when provider pricing supports it.

## Safe Optimizations

- Keep traffic with the same model, user, and stable prompt prefix on the same upstream organization/key when capacity allows.
- Preserve user message order and content exactly.
- Allow advanced users to pass provider-supported cache hints such as `prompt_cache_key` only when the upstream supports them.
- Report cache hit rate by model and user so pricing can be adjusted after real traffic data exists.

## Excluded From V1

- Cross-user semantic response cache.
- Prompt rewriting, prompt reordering, or hidden system prompt injection.
- Agent template cache optimization.
- Claims that every request will be cheaper because cache behavior depends on provider support and exact prompt structure.
