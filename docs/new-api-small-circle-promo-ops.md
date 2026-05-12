# New API Small Circle Promo Ops Runbook

This runbook turns the friend-only New API launch into a lightweight promotion and operations system. It does not require a custom landing page, payment automation, a frontend fork, or a new support stack. Use New API's built-in site settings, console content panels, FAQ, announcements, and manual admin workflows.

## Positioning

Use one public positioning line:

```text
Lihan AI Relay: 小范围 AI API 中转与多模型接入服务。
```

Audience:

- Friends, trusted referrals, developers, AI client users, and small automation users.
- Users who can accept manual activation, fair use, and a small-circle beta service.

Allowed promises:

- Stable access is prioritized.
- Multiple model choices are available through one API base URL.
- Manual support is available in the private group.

Avoid these claims:

- Unlimited usage.
- Lowest price.
- Official USD balance equivalence.
- Public resale rights.
- Strong SLA or guaranteed upstream availability.

## New API Paste Pack

Paste these values in the New API admin console before sending users to the site. Keep the runtime on the official image unless the launch runbook explicitly says to use the temporary rollback image.

### System Settings

| Setting | Value |
| --- | --- |
| `SystemName` | `Lihan AI Relay` |
| `ServerAddress` | `https://api.lihan3238.com` |
| `Logo` | Leave empty until a stable logo URL exists. |
| `general_setting.docs_link` | `https://api.lihan3238.com/about` |
| `Footer` | Paste the footer HTML below. |

Footer HTML:

```html
<span>Private beta · Manual activation · Fair use · station quota is not official USD balance</span>
```

### HomePageContent

Paste into `HomePageContent`:

````markdown
# Lihan AI Relay

小范围 AI API 中转与多模型接入服务。适合写代码、AI 客户端、小自动化、学习和测试场景。

**API Base URL**

```text
https://api.lihan3238.com/v1
```

## 三步接入

1. 登录控制台，在「令牌」页面创建 API Key。
2. 把客户端里的 OpenAI-compatible base URL 改成 `https://api.lihan3238.com/v1`。
3. 选择可用模型后开始调用；具体模型名以控制台和 `/v1/models` 返回为准。

## 适合

- 编程工具、AI 客户端、轻量自动化、学习测试。
- 能接受小范围内测、手动开通、群内支持的用户。

## 不适合

- 转售、共享账号、公开分发 Key。
- 压测、异常高并发、批量生产任务未提前沟通。
- 只追求最低价或无限量使用。

> station quota / 站内额度是本站内部计量口径，不是官方真实 USD 余额。服务处于熟人内测阶段，开通和套餐调整均由管理员手动处理。
````

### About

Paste into `About`:

```markdown
# 关于 Lihan AI Relay

Lihan AI Relay 是一个熟人小范围使用的 AI API relay。目标不是公开卖量，而是把多模型 API 接入、额度管理、手动支持和基础运维整理成一个更稳定的入口。

## 我们提供什么

- 一个 OpenAI-compatible API base URL：`https://api.lihan3238.com/v1`
- 多模型接入与统一令牌管理。
- New API 控制台里的用量、额度、日志和令牌管理。
- 微信/QQ 群内的手动开通、问题反馈和更新公告。

## 使用边界

- station quota / 站内额度是本站内部计量口径，不是官方真实 USD 余额。
- 上游模型、价格、额度和可用性可能变化，群公告优先。
- 禁止转售、共享账号、公开分发 Key、异常高并发和绕过限制的使用方式。
- 生产、批量或高频任务请先私聊确认。

## 适合谁

- 写代码、用 AI 客户端、做小工具、学习测试的朋友。
- 希望少折腾 base URL 和多模型配置的人。
- 能接受小范围内测、手动开通和 fair use 规则的人。

## 不适合谁

- 需要强 SLA、合同、发票或企业级支持的人。
- 要公开转卖、多人共享或跑压测的人。
- 只追求最低价或无限量的人。

如需试用，请私聊管理员或在内测群里说明使用场景。
```

### Notice

Paste into `Notice`:

```markdown
Lihan AI Relay 目前处于熟人内测阶段。开通、套餐调整和高频使用请先联系管理员。

使用规则：不要转售、不要共享账号或 API Key、不要跑异常高并发。station quota / 站内额度不是官方真实 USD 余额。上游波动、模型调整和维护信息以群公告为准。
```

### Announcements

If editing raw `console_setting.announcements`, paste this JSON. If using the visual editor, create the same entries manually.

```json
[
  {
    "id": 1,
    "content": "Lihan AI Relay 熟人内测开启：优先服务写代码、AI 客户端、小自动化、学习测试场景。",
    "publishDate": "2026-05-13T00:00:00+08:00",
    "type": "ongoing",
    "extra": "手动开通 · fair use · 禁止转售共享"
  },
  {
    "id": 2,
    "content": "API Base URL：`https://api.lihan3238.com/v1`。创建 API Key 后，把客户端的 OpenAI-compatible base URL 改成这个地址。",
    "publishDate": "2026-05-13T00:00:00+08:00",
    "type": "default",
    "extra": "具体模型名以控制台和 /v1/models 为准"
  }
]
```

### API Info

If editing raw `console_setting.api_info`, paste this JSON. If using the visual editor, create the same entries manually.

```json
[
  {
    "id": 1,
    "url": "https://api.lihan3238.com/v1",
    "route": "/v1",
    "description": "OpenAI-compatible API base URL",
    "color": "blue"
  },
  {
    "id": 2,
    "url": "https://api.lihan3238.com",
    "route": "console",
    "description": "Login, create API keys, check quota and logs",
    "color": "green"
  }
]
```

### FAQ

If editing raw `console_setting.faq`, paste this JSON. If using the visual editor, create the same entries manually.

```json
[
  {
    "id": 1,
    "question": "API Base URL 填什么？",
    "answer": "OpenAI-compatible 客户端填 `https://api.lihan3238.com/v1`。如果客户端要求只填主域名，再按该客户端文档改成 `https://api.lihan3238.com`。"
  },
  {
    "id": 2,
    "question": "怎么创建 API Key？",
    "answer": "登录控制台后进入「令牌」页面，新建令牌并复制。不要把 Key 发到群里或截图公开；泄露后请立刻删除旧 Key 并重新创建。"
  },
  {
    "id": 3,
    "question": "station quota / 站内额度是什么？",
    "answer": "station quota 是本站内部用量计量口径，不是官方真实 USD 余额，也不代表上游账户余额。套餐、倍率和重置规则以管理员公告为准。"
  },
  {
    "id": 4,
    "question": "支持哪些客户端？",
    "answer": "能配置 OpenAI-compatible base URL 的客户端通常都可以尝试，例如 Cherry Studio、Chatbox、Lobe、OpenAI SDK、自建网页客户端等。Claude Code、Codex、OpenCode 等 CLI 场景可能需要额外按客户端协议配置。"
  },
  {
    "id": 5,
    "question": "模型列表以哪里为准？",
    "answer": "以控制台展示和 `/v1/models` 实时返回为准。上游模型、额度、价格和可用性会变化，群公告优先。"
  },
  {
    "id": 6,
    "question": "遇到错误怎么反馈？",
    "answer": "请按格式发给管理员：时间、模型名、客户端、是否流式、错误信息、request id、是否可复现。不要直接发送 API Key。"
  },
  {
    "id": 7,
    "question": "可以共享账号或转售吗？",
    "answer": "不可以。熟人内测只允许本人使用。共享账号、公开分发 Key、转售、压测或异常高并发可能会被限速、降组或暂停服务。"
  },
  {
    "id": 8,
    "question": "退款或补偿怎么处理？",
    "answer": "内测阶段以人工沟通为准。短时上游波动通常不逐笔补偿；长时间不可用、套餐配置错误或管理员操作失误，会按实际情况人工处理。"
  }
]
```

## Group Operations

Create one primary group:

```text
Lihan AI Relay 内测群
```

Group profile:

- Entry: known friends or trusted referrals only.
- Purpose: onboarding, package questions, support, model requests, and status updates.
- Support channel: group for common issues, private chat for payment, account identity, abnormal usage, or sensitive logs.

User segments:

| Segment | Meaning | Operator action |
| --- | --- | --- |
| Watcher | Joined group, not activated | Point to announcement and FAQ. |
| Trial user | Low quota trial | Confirm they can create Key and send one request. |
| Paid user | Active package | Keep in `default` unless explicitly upgraded. |
| High-frequency user | Heavy or priority user | Review usage, then manually assign `vip` if appropriate. |

Group rules to pin:

```text
群规：
1. 不共享账号，不转售，不公开分发 API Key。
2. 不跑压测、异常高并发或未经确认的批量生产任务。
3. 不要把 API Key 发群里；Key 泄露请立刻删除重建。
4. station quota / 站内额度不是官方真实 USD 余额。
5. 上游波动、维护、模型变化和套餐调整以群公告为准。
6. 报错请按固定格式反馈：时间 / 模型 / 客户端 / 是否流式 / 错误信息 / request id / 是否可复现。
```

Pinned group announcement:

```text
欢迎来到 Lihan AI Relay 内测群。

控制台：https://api.lihan3238.com
API Base URL：https://api.lihan3238.com/v1

开通流程：
1. 私聊管理员说明使用场景。
2. 选择试用或套餐。
3. 管理员手动开通后，登录控制台创建 API Key。
4. 把客户端 base URL 改成上面的地址。

适合：写代码、AI 客户端、小自动化、学习测试。
不适合：转售、共享、压测、异常高并发、最低价无限量诉求。

报错格式：时间 / 模型 / 客户端 / 是否流式 / 错误信息 / request id / 是否可复现。
不要在群里发送 API Key。
```

Fault report template:

```text
故障反馈：
- 时间：
- 用户名：
- 模型：
- 客户端 / SDK：
- API 路径：
- 是否流式：
- 错误信息：
- request id：
- 是否可复现：
- 最近是否改过配置：
```

Weekly update template:

```text
本周 Lihan AI Relay 更新：
1. 模型/渠道变化：
2. 已知问题：
3. 维护窗口：
4. 使用提醒：

提醒：station quota / 站内额度不是官方真实 USD 余额；不要共享账号或 API Key；高频/批量任务先私聊确认。
```

## WeChat Moments And QQ Zone

Keep the first wave visible only to friends. Do not post broad public ads.

Posting rhythm:

1. Day 1: internal beta announcement.
2. Day 2-3: short setup tutorial or client screenshot.
3. Day 5-7: stability and usage rules.
4. Later: only model updates, package changes, incidents, or recovery notices.

WeChat Moments first post:

```text
我最近整理了一个小范围 AI API relay，先给熟人内测。

它适合：
- 写代码、接 AI 客户端、做小自动化
- 学习测试多模型 API
- 想少折腾 base URL 和模型切换的人

它不适合：
- 转售、共享账号、公开分发 Key
- 压测、异常高并发
- 追求最低价或无限量

目前是手动开通，优先稳定和可控。station quota / 站内额度是本站内部计量口径，不是官方真实 USD 余额。

想试的可以私聊我，我会按使用场景开通试用或套餐。
```

WeChat Moments tutorial follow-up:

```text
Lihan AI Relay 接入方式很简单：

1. 登录控制台创建 API Key。
2. 客户端 base URL 填：
   https://api.lihan3238.com/v1
3. 选择模型后调用。

一般能配置 OpenAI-compatible base URL 的客户端都可以试，比如 Cherry Studio、Chatbox、Lobe、OpenAI SDK、自建网页客户端等。

还是熟人内测，不公开卖量；遇到问题直接群里按格式反馈。
```

QQ Zone long post:

```text
Lihan AI Relay 熟人内测说明

这是一个小范围 AI API 中转与多模型接入服务。目标不是公开卖量，而是给熟人和朋友一个稳定、可控、容易接入的 API 入口。

适合：
1. 写代码或使用 AI 编程工具。
2. 使用 Cherry Studio、Chatbox、Lobe、自建网页客户端等 AI 客户端。
3. 做小自动化、学习测试、多模型对比。

基础信息：
- 控制台：https://api.lihan3238.com
- API Base URL：https://api.lihan3238.com/v1
- 接入协议：OpenAI-compatible
- 开通方式：私聊管理员，手动开通

使用边界：
- station quota / 站内额度不是官方真实 USD 余额。
- 不共享账号，不公开分发 API Key，不转售。
- 不跑压测、异常高并发或未经确认的批量生产任务。
- 上游模型、价格、额度和可用性可能变化，以群公告为准。

想试用的朋友可以私聊我，说明大概使用场景。我会先小范围开通，观察稳定性和支持压力。
```

## Activation And Support Templates

Activation path:

1. User sees WeChat Moments or QQ Zone post.
2. User sends private message or joins group.
3. User reads group announcement and site FAQ.
4. User chooses trial or package.
5. Operator receives payment outside New API.
6. Operator creates or updates the New API user.
7. Operator assigns `default` or `vip`.
8. Operator binds the matching subscription.
9. Operator sends the activation message below.

Activation private message:

```text
已开通 Lihan AI Relay。

控制台：https://api.lihan3238.com
API Base URL：https://api.lihan3238.com/v1

使用步骤：
1. 登录控制台。
2. 进入「令牌」页面创建 API Key。
3. 在客户端里把 OpenAI-compatible base URL 改成上面的地址。
4. 选择模型后调用；模型名以控制台和 /v1/models 返回为准。

注意：
- station quota / 站内额度不是官方真实 USD 余额。
- 不要共享账号或 API Key。
- 遇到问题按格式反馈：时间 / 模型 / 客户端 / 是否流式 / 错误信息 / request id / 是否可复现。
```

Trial follow-up:

```text
你可以先用试用额度确认三件事：
1. 能登录控制台并创建 API Key。
2. 客户端能连上 `https://api.lihan3238.com/v1`。
3. 常用模型能完成你的核心场景。

如果这三步都没问题，再考虑正式套餐。
```

Incident announcement:

```text
服务状态更新：
- 影响范围：
- 开始时间：
- 当前状态：
- 临时建议：
- 下一次更新：

说明：上游波动或维护期间，可能出现部分模型不可用、延迟升高或请求失败。请先暂停批量任务，等待群公告更新。
```

Package change announcement:

```text
套餐/额度调整说明：
- 调整内容：
- 生效时间：
- 影响用户：
- 原因：

已开通用户如受影响，可以私聊管理员确认处理方式。station quota / 站内额度仍为本站内部计量口径，不是官方真实 USD 余额。
```

## Operating Cadence

Daily:

- Process manual activation and package changes.
- Check group fault reports and repeated questions.
- Review unusual high-frequency users before granting `vip`.
- Keep sensitive data, API Keys, and payment details out of the group.

Weekly:

- Send one concise group update.
- Update FAQ if two or more users hit the same issue.
- Review package wording and make sure it does not imply unlimited usage or official USD balance.
- Run local E2E before production changes that affect New API behavior.

Before expanding beyond friends:

- At least 1-2 real users complete self-service setup from the pinned announcement.
- The FAQ answers the top repeated issues.
- Manual activation time stays acceptable.
- No unresolved quota wording confusion remains.
- Local E2E passes against the restored stack.

## Acceptance Checklist

- New API site settings include `Lihan AI Relay`, `https://api.lihan3238.com`, footer, HomePageContent, About, Notice, API Info, FAQ, and Announcements.
- The copy says `station quota is not official USD balance`.
- The copy does not promise unlimited usage, lowest price, resale rights, or strong SLA.
- The group announcement is pinned in WeChat and QQ if both groups are used.
- Activation and fault report templates are used consistently.
- First wave promotion remains visible only to friends or trusted referrals.
- Any production behavior change still goes through the local E2E flow documented in `docs/browser-e2e-runbook.md`.
