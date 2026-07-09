# lihan_ai Agent Guide

lihan-cards mode: engineering

This repo is intentionally a small production wrapper around upstream New API
and upstream CLIProxyAPI. Do not reintroduce vendored upstream trees, local
frontend builds, generated Spec Kit assets, Playwright scaffolding, or Caddy
unless Lihan explicitly asks for a new design.

## Scope

- Runtime: `calciumion/new-api`, `eceasy/cli-proxy-api`, PostgreSQL, Redis.
- Ingress: `cloudflare/cloudflared` as a separate Komodo stack joining the
  shared Docker network.
- Management: Komodo observes and updates Docker Compose stacks; secrets stay
  on the target host in `.env.production` and service config files.

## Safety

- Never print real `.env.production`, CPA config/auth files, tunnel
  credentials, database dumps, cookies, tokens, or private keys.
- Do not restore databases or delete volumes without explicit approval.
- Prefer upstream images and Komodo Procedures over local forks or bespoke CI.
