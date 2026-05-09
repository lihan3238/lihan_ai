# Handoff: Production Deploy Lessons Hardening

This feature captures real production deployment lessons after the first Hostinger VPS launch. The implementation is wrapper-only and should not change `vendor/new-api`.

Key risks addressed:

- URL-special DB/Redis passwords break New API `SQL_DSN` and Redis URL parsing.
- Backup verification warnings were caused by missing `--env-file` in Compose calls.
- Caddy may fail at host port binding or ACME DNS even when New API is healthy.
- CPA must run on the same Docker network as New API, but its UI must not be public.

CPA policy:

- Official CPA files are vendored as upstream references.
- Production uses our compose overlay.
- Management UI is only exposed on `127.0.0.1:${CPA_UI_PORT:-8317}` when the UI override is included and should be accessed through SSH tunneling.
