# CPA Quota Homepage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken New API custom homepage embed with a standalone public homepage that renders a generic multi-provider CPA quota snapshot.

**Architecture:** New API `HomePageContent` will point directly to `/cpa-quota/home.html`, avoiding Markdown iframe sandboxing. Static public files under `public/cpa-quota/` read only sanitized JSON from `/cpa-quota/data/quota-snapshot.json`, with legacy `codex-quota.json` as a read fallback. CPA management APIs remain private.

**Tech Stack:** POSIX shell, Python 3 JSON sanitizer, static HTML/CSS/JS, Docker Compose/Caddy, existing shell test suite.

## Global Constraints

- Do not expose CPA `8317` or `/v0/management/*` publicly.
- Do not publish provider tokens, account emails, API keys, cookies, or raw management API responses.
- Keep legacy `codex-quota.json` readers working while adding generic `quota-snapshot.json`.
- Production changes require backup before mutating `HomePageContent`.

---

### Task 1: Static Homepage And Generic Widget Contract

**Files:**
- Create: `public/cpa-quota/home.html`
- Modify: `public/cpa-quota/widget.html`
- Modify: `tests/cpa-quota-snapshot.test.sh`

**Interfaces:**
- Consumes: sanitized snapshot at `data/quota-snapshot.json`
- Produces: public pages that render `providers[].accounts[].windows[]`

- [x] Add failing tests requiring `home.html`, `quota-snapshot.json` fetch, legacy fallback, and no iframe-based homepage embed.
- [x] Implement static `home.html` as the full custom homepage.
- [x] Update `widget.html` to render the generic provider/account/window schema.
- [x] Run `bash tests/cpa-quota-snapshot.test.sh`.

### Task 2: Generic Snapshot Sanitizer

**Files:**
- Modify: `ops/cpa-quota-snapshot.sh`
- Modify: `tests/cpa-quota-snapshot.test.sh`

**Interfaces:**
- Consumes: raw JSON in either old Codex-only shape, normalized generic shape, or an array of provider/account items.
- Produces: `quota-snapshot.json` with no secret-looking fields.

- [x] Add failing tests for multiple providers and multiple accounts.
- [x] Normalize provider, label, plan, status, windows, reset timestamps, and remaining/used percent.
- [x] Keep secret denylist assertions.
- [x] Run `bash tests/cpa-quota-snapshot.test.sh`.

### Task 3: Docs And Log Research

**Files:**
- Modify: `docs/cpa-runbook.md`
- Modify: `docs/zh-CN/cpa-runbook.md`

**Interfaces:**
- Produces: clear operator guidance for manual snapshot publishing and logging limitations.

- [x] Document that `HomePageContent` should be `https://api.lihan3238.com/cpa-quota/home.html`.
- [x] Document that CPA file/request logs can help audit refresh attempts but are not a safe source for public snapshots because management API responses may contain sensitive data or are not persisted in a stable sanitized shape.
- [x] Run docs i18n tests.

### Task 4: Production Deploy

**Files:**
- No new code files beyond Tasks 1-3.

**Interfaces:**
- Consumes: release deploy script and production DB option.
- Produces: production `HomePageContent` set to the new standalone URL.

- [x] Run full local tests and compose render.
- [ ] Commit and push.
- [ ] Backup production database and `HomePageContent`.
- [ ] Deploy release with `prepare`, `smoke`, `promote`.
- [ ] Set `HomePageContent` to `https://api.lihan3238.com/cpa-quota/home.html`.
- [ ] Verify homepage, widget, runtime health, and quota snapshot 404/200 behavior.
