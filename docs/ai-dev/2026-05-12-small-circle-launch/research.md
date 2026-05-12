# Research

## New API Capability

- New API has built-in site settings, announcements, About/API info, FAQ, pricing display, groups, subscription plans, and manual user subscription management.
- The package launch can be represented as configuration first: station quota wording, `default` / `vip` groups, and manual activation.

## Community Signals

- Linux.do discussions show that relay users care about official supply, stability, whether the relay is multi-hop, model freshness, and coding-tool compatibility.
- The launch copy should avoid low-price unlimited claims and should not generate Linux.do promotional posts.

## Frontend Patch Status

- Local New API submodule commit `f80e8ea6` contains the `5741c359` fix for `DropdownMenuItem onSelect` compatibility plus Docker build-context cleanup.
- Upstream issue #4692 and PR #4787 are not treated as shipped until the official image includes the equivalent fix.
- The wrapper should verify the admin Users page with browser E2E before choosing official or temporary custom image.
