# Research

## Context

Production already has focused scripts for runtime verification, PostgreSQL backup verification, and restic offsite backup. The missing layer is a cron-safe wrapper that gives operators stable commands, shared logs, status files, and optional alerts.

## Decision

Use a small shell wrapper around existing scripts instead of adding a new monitoring service. Keep runtime health, local backup, and offsite backup as separate cron entries so failures are easy to diagnose and schedules can differ.

## Alternatives Considered

- Uptime Kuma automation: deferred because monitor tokens and UI state should stay outside git.
- One daily all-in-one cron: rejected because runtime outages should be detected more frequently than backup jobs.
- Edge monitoring: deferred because the current production path is origin plus Cloudflare Tunnel.
