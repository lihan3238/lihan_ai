# User Guide

Lihan AI Relay is a small-scope AI API relay for invited users. It provides an OpenAI-compatible API endpoint and manually supported access to multiple models.

## Service Boundary

Good fit:

- AI clients that support OpenAI-compatible APIs.
- Coding assistants and local automation.
- Learning, testing, and personal productivity.
- Small scripts with moderate request volume.

Not a good fit:

- Account sharing or resale.
- Stress testing, scraping, or abnormal high concurrency.
- Workloads that require a formal SLA.
- Treating station quota as official upstream USD balance.

## Account And Key

1. Open `https://api.lihan3238.com`.
2. Log in with your invited account.
3. Create an API key in the console.
4. Store the key in your password manager or local secret store.
5. Delete old keys you no longer use.

Never paste API keys into public chat, screenshots, GitHub issues, or client logs.

## Client Configuration

Use these defaults:

| Field | Value |
| --- | --- |
| Provider type | OpenAI-compatible |
| API Base URL | `https://api.lihan3238.com/v1` |
| API Key | Your New API token |
| Model | Pick from the console or group announcement |

Some clients ask for the host and append `/v1` automatically. In that case, use `https://api.lihan3238.com`.

## API Smoke Test

Replace `YOUR_KEY` and model name:

```bash
curl https://api.lihan3238.com/v1/chat/completions \
  -H "Authorization: Bearer YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-5.1",
    "messages": [
      { "role": "user", "content": "Say hello in one sentence." }
    ]
  }'
```

## Quota And Packages

- Quota is managed by this relay site.
- Package names and limits may differ from upstream provider billing units.
- Upstream availability, model routing, and pricing can change.
- For production or batch tasks, confirm with the maintainer before running.

## Common Problems

### 401 or unauthorized

Check that the API key is copied completely and belongs to the active account.

### Model not found

Use a model listed in the console or the latest group announcement. Some clients cache model lists; restart the client if needed.

### Streaming disconnects

Try non-streaming once. If non-streaming works, report the client name, model, and streaming setting.

### Quota looks different from official USD

That is expected. The relay uses station quota and package rules, not official USD balance.

## Fault Report Template

```text
Time:
Account username:
Client:
Model:
Streaming: yes/no
Error message:
Request id, if shown:
Approximate token/input size:
Can you reproduce it:
```
