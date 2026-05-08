# Research

## Sources
- Official documentation: New API channel test and status endpoints, Uptime Kuma project wiki status page and reverse proxy guidance, Caddy reverse proxy docs.
- Mature adjacent projects: LiteLLM and Portkey emphasize health checks, fallback/retry, routing, and budget-aware gateway operations; Helicone emphasizes latency, error, cost, and alert observability.
- GitHub issues or release notes: Not required for V1 because this change is wrapper-only and read-only.
- Community discussions: Used only to confirm common Uptime Kuma deployment shape; implementation relies on official/project documentation and local compose.

## Common Practice
AI gateway operators separate internal diagnostics from public status. Internal views include channel IDs, error rates, latency, routing, balances, and action hints. Public status pages show coarse components such as API availability, model pool health, billing, and maintenance.

## Risks
- A public status page can leak operational details if monitor names or incident text include provider/channel names.
- Automatic disabling can cause cascading capacity loss if thresholds are too aggressive.
- Real chat probes cost tokens and can pollute logs if run too frequently.
- Caddy config can become fragile if optional status domains are inserted into the active config without a configured DNS record.

## Decision
Build a read-only channel health advisor for internal use and document Uptime Kuma as the user-facing status page. Do not auto-disable channels, do not auto-create Kuma monitors, and do not change the active Caddyfile by default.
